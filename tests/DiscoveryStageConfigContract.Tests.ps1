$repoPath = Split-Path -Parent $PSScriptRoot
$coreCyclerPath = Join-Path $repoPath 'script-corecycler.ps1'

function Import-CoreCyclerFunctionForStageConfigContract {
    param(
        [Parameter(Mandatory=$true)] [String] $Name
    )

    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($coreCyclerPath, [ref] $tokens, [ref] $errors)
    if ($errors.Count -ne 0) {
        throw 'Could not parse script-corecycler.ps1.'
    }

    $functionAst = $ast.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $Name
    }, $true) | Select-Object -First 1

    if (!$functionAst) {
        throw ('Could not find function ' + $Name + ' in script-corecycler.ps1.')
    }

    $definition = $functionAst.Extent.Text -replace ('(?m)^function\s+' + [Regex]::Escape($functionAst.Name)), ('function global:' + $Name)
    Invoke-Expression $definition
}

Describe 'Discovery stage config input contract' {
    BeforeEach {
        Remove-Item -Path Function:\global:Resolve-CoreCyclerConfigInput -ErrorAction Ignore
        Remove-Item -Path Function:\global:Assert-CoreCyclerConfigMayBeRepaired -ErrorAction Ignore
        Remove-Item -Path Function:\global:Get-Settings -ErrorAction Ignore
        Import-CoreCyclerFunctionForStageConfigContract -Name 'Resolve-CoreCyclerConfigInput'
        Import-CoreCyclerFunctionForStageConfigContract -Name 'Assert-CoreCyclerConfigMayBeRepaired'
        Import-CoreCyclerFunctionForStageConfigContract -Name 'Get-Settings'
    }

    It 'keeps the legacy config path when no explicit child config is supplied' {
        $defaultPath = Join-Path $TestDrive 'config.ini'

        $result = Resolve-CoreCyclerConfigInput -ConfigPath '' -DefaultPath $defaultPath

        $result.Path | Should Be $defaultPath
        $result.IsExplicit | Should Be $false
    }

    It 'uses an existing explicit child config without rewriting the legacy config path' {
        $defaultPath = Join-Path $TestDrive 'config.ini'
        $stageConfigPath = Join-Path $TestDrive 'discovery-stage.ini'
        [System.IO.File]::WriteAllText($defaultPath, 'legacy-config')
        [System.IO.File]::WriteAllText($stageConfigPath, 'stage-config')

        $result = Resolve-CoreCyclerConfigInput -ConfigPath $stageConfigPath -DefaultPath $defaultPath

        $result.Path | Should Be ([System.IO.Path]::GetFullPath($stageConfigPath))
        $result.IsExplicit | Should Be $true
        [System.IO.File]::ReadAllText($defaultPath) | Should Be 'legacy-config'
    }

    It 'rejects a missing explicit child config rather than falling back to or creating config.ini' {
        $defaultPath = Join-Path $TestDrive 'config.ini'
        $missingStageConfigPath = Join-Path $TestDrive 'missing-stage.ini'
        [System.IO.File]::WriteAllText($defaultPath, 'legacy-config')

        { Resolve-CoreCyclerConfigInput -ConfigPath $missingStageConfigPath -DefaultPath $defaultPath } | Should Throw 'The explicit config path does not exist or is not a file.'

        [System.IO.File]::ReadAllText($defaultPath) | Should Be 'legacy-config'
        (Test-Path -LiteralPath $missingStageConfigPath) | Should Be $false
    }

    It 'allows legacy config recovery but fails closed instead of repairing an explicit child config' {
        { Assert-CoreCyclerConfigMayBeRepaired -IsExplicit $false } | Should Not Throw
        { Assert-CoreCyclerConfigMayBeRepaired -IsExplicit $true } | Should Throw 'An explicit config path cannot be created or repaired.'
    }

    It 'does not repair a malformed explicit config through Get-Settings' {
        $stageConfigPath = Join-Path $TestDrive 'malformed-stage.ini'
        $defaultConfigPath = Join-Path $TestDrive 'default.config.ini'
        [System.IO.File]::WriteAllText($stageConfigPath, 'malformed-stage-config')
        [System.IO.File]::WriteAllText($defaultConfigPath, 'legacy-default-config')

        $global:configUserPath = $stageConfigPath
        $global:configUserPathIsExplicit = $true
        $global:configDefaultPath = $defaultConfigPath
        $global:DEFAULT_SETTINGS_STRING = 'legacy-repair-content'
        $global:scriptStartDateTime = '2026-08-15_06-45-00'
        $global:logFilePathAbsolute = [String] $TestDrive + '\\'
        $global:logFileName = 'initial.log'

        function global:Write-DebugText { param([String] $text) }
        function global:Write-ColorText { param([String] $text) }
        function global:Import-Settings {
            param($Path)
            if ($Path -eq 'DEFAULT') {
                return @{ Logging = @{ name = 'CoreCycler' } }
            }
            throw 'malformed config'
        }

        { Get-Settings } | Should Throw 'An explicit config path cannot be created or repaired.'
        [System.IO.File]::ReadAllText($stageConfigPath) | Should Be 'malformed-stage-config'
        [System.IO.File]::ReadAllText($defaultConfigPath) | Should Be 'legacy-default-config'
    }
}
