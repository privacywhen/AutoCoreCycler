Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot '..\helpers\CoreCyclerPhaseConfig.psm1'
Import-Module $modulePath -Force

$Script:TestCount = 0

function Assert-True {
    param(
        [Parameter(Mandatory=$true)] [Bool] $Condition,
        [Parameter(Mandatory=$false)] [String] $Message = 'Expected condition to be true.'
    )

    if (!$Condition) {
        throw($Message)
    }
}

function Assert-MatchText {
    param(
        [Parameter(Mandatory=$true)] [String] $Text,
        [Parameter(Mandatory=$true)] [String] $Pattern
    )

    if ($Text -NotMatch $Pattern) {
        throw('Expected text to match pattern: ' + $Pattern)
    }
}

function Assert-Throws {
    param(
        [Parameter(Mandatory=$true)] [ScriptBlock] $ScriptBlock,
        [Parameter(Mandatory=$false)] [String] $MessagePattern
    )

    $threw = $false

    try {
        & $ScriptBlock | Out-Null
    }
    catch {
        $threw = $true

        if ($MessagePattern -and $_.Exception.Message -NotMatch $MessagePattern) {
            throw('Expected exception matching "' + $MessagePattern + '", got: ' + $_.Exception.Message)
        }
    }

    if (!$threw) {
        throw('Expected script block to throw.')
    }
}

function Assert-SameNormalizedText {
    param(
        [Parameter(Mandatory=$true)] [String] $Actual,
        [Parameter(Mandatory=$true)] [String] $Expected
    )

    $normalizedActual = $Actual.Replace("`r`n", "`n").TrimEnd()
    $normalizedExpected = $Expected.Replace("`r`n", "`n").TrimEnd()

    if ($normalizedActual -ne $normalizedExpected) {
        throw('Generated text did not match the expected fixture.')
    }
}

function It {
    param(
        [Parameter(Mandatory=$true)] [String] $Name,
        [Parameter(Mandatory=$true)] [ScriptBlock] $Body
    )

    & $Body
    $Script:TestCount++
    Write-Host ('PASS: ' + $Name)
}

It 'emits WHEA defaults for baseline configs' {
    $phase = New-CoreCyclerPhase -Name 'baseline-sanity' -Type BaselineSanity
    $ini = ConvertTo-CoreCyclerIni -Phase $phase

    Assert-MatchText $ini '(?m)^lookForWheaErrors = 1\r?$'
    Assert-MatchText $ini '(?m)^treatWheaWarningAsError = 1\r?$'
}

It 'defaults automated discovery maxValue to zero' {
    $phase = New-CoreCyclerPhase -Name 'coarse-discovery' -Type CoarseIsolatedDiscovery
    $ini = ConvertTo-CoreCyclerIni -Phase $phase

    Assert-MatchText $ini '(?m)^enableAutomaticAdjustment = 1\r?$'
    Assert-MatchText $ini '(?m)^maxValue = 0\r?$'
    Assert-MatchText $ini '(?m)^setVoltageOnlyForTestedCore = 1\r?$'
    Assert-MatchText $ini '(?m)^voltageValueForNotTestedCores = 0\r?$'
}

It 'rejects positive maxValue by default' {
    $phase = New-CoreCyclerPhase -Name 'unsafe-positive-max' -Type CoarseIsolatedDiscovery -Sections @{
        AutomaticTestMode = @{
            maxValue = 1
        }
    }

    Assert-Throws { ConvertTo-CoreCyclerIni -Phase $phase } 'Positive Curve Optimizer'
}

It 'rejects positive startValues by default' {
    $phase = New-CoreCyclerPhase -Name 'unsafe-positive-start' -Type FineIsolatedDiscovery -Sections @{
        AutomaticTestMode = @{
            startValues = '-20, 1, 0'
        }
    }

    Assert-Throws { ConvertTo-CoreCyclerIni -Phase $phase } 'Positive Curve Optimizer'
}

It 'rejects positive non-tested-core CO by default' {
    $phase = New-CoreCyclerPhase -Name 'unsafe-positive-untested' -Type CoarseIsolatedDiscovery -Sections @{
        AutomaticTestMode = @{
            voltageValueForNotTestedCores = 1
        }
    }

    Assert-Throws { ConvertTo-CoreCyclerIni -Phase $phase } 'Positive Curve Optimizer'
}

It 'allows positive CO only with explicit opt-in' {
    $phase = New-CoreCyclerPhase -Name 'explicit-positive-opt-in' -Type CoarseIsolatedDiscovery -Sections @{
        AutomaticTestMode = @{
            maxValue = 2
        }
    }

    $ini = ConvertTo-CoreCyclerIni -Phase $phase -AllowPositiveCurveOptimizer
    Assert-MatchText $ini '(?m)^# WARNING: Positive Curve Optimizer values were explicitly allowed'
    Assert-MatchText $ini '(?m)^maxValue = 2\r?$'
}

It 'exposes conservative Ryzen generation profile defaults' {
    $ryzen5000 = Get-CoreCyclerRyzenGenerationProfile Ryzen5000
    $ryzen7000 = Get-CoreCyclerRyzenGenerationProfile Ryzen7000
    $ryzen8000 = Get-CoreCyclerRyzenGenerationProfile Ryzen8000
    $ryzen9000 = Get-CoreCyclerRyzenGenerationProfile Ryzen9000

    Assert-True ([Int] $ryzen5000.MinimumCurveOptimizerValue -eq -30)
    Assert-True ([Int] $ryzen7000.MinimumCurveOptimizerValue -eq -50)
    Assert-True ([Int] $ryzen8000.MinimumCurveOptimizerValue -eq -50)
    Assert-True ([Int] $ryzen9000.MinimumCurveOptimizerValue -eq -50)
    Assert-True ([String] $ryzen5000.Sections.yCruncher.mode -eq '19-ZN2 ~ Kagari')
    Assert-True ([String] $ryzen7000.Sections.yCruncher.mode -eq '22-ZN4 ~ Kizuna')
    Assert-True ([String] $ryzen8000.Sections.yCruncher.mode -eq '22-ZN4 ~ Kizuna')
    Assert-True ([String] $ryzen9000.Sections.yCruncher.mode -eq '24-ZN5 ~ Komari')
}

It 'rejects Ryzen 5000 profile CO values below minus 30' {
    $phase = New-CoreCyclerPhase -Name 'ryzen5000-too-negative' -Type CoarseIsolatedDiscovery -RyzenGeneration Ryzen5000 -Sections @{
        AutomaticTestMode = @{
            startValues = '-31, -20, -10, 0'
        }
    }

    Assert-Throws { ConvertTo-CoreCyclerIni -Phase $phase } 'below the Ryzen 5000 profile minimum of -30'
}

It 'allows Ryzen 7000 profile CO values down to minus 50' {
    $phase = New-CoreCyclerPhase -Name 'ryzen7000-floor' -Type FineIsolatedDiscovery -RyzenGeneration Ryzen7000 -Sections @{
        AutomaticTestMode = @{
            startValues = '-50, -45, -20, 0'
        }
    }

    $ini = ConvertTo-CoreCyclerIni -Phase $phase
    Assert-MatchText $ini '(?m)^# RyzenMinimumCurveOptimizer = -50\r?$'
    Assert-MatchText $ini '(?m)^startValues = -50, -45, -20, 0\r?$'
}

It 'accepts canonical phase ordering' {
    $phases = @(
        New-CoreCyclerPhase -Name 'baseline' -Type BaselineSanity
        New-CoreCyclerPhase -Name 'coarse' -Type CoarseIsolatedDiscovery
        New-CoreCyclerPhase -Name 'fine' -Type FineIsolatedDiscovery
        New-CoreCyclerPhase -Name 'combined' -Type CombinedMapValidation
        New-CoreCyclerPhase -Name 'transition' -Type TransitionValidation
    )

    Assert-True (Test-CoreCyclerPhaseSequence -Phases $phases)
}

It 'rejects phase ordering that puts fine discovery before coarse discovery' {
    $fine = New-CoreCyclerPhase -Name 'fine-too-early' -Type FineIsolatedDiscovery -Order 20
    $coarse = New-CoreCyclerPhase -Name 'coarse-too-late' -Type CoarseIsolatedDiscovery -Order 30

    Assert-Throws { Test-CoreCyclerPhaseSequence -Phases @($fine, $coarse) } 'Invalid phase order'
}

It 'emits y-cruncher validation phases without Prime95 settings' {
    $phase = New-CoreCyclerPhase -Name 'alternate-validation' -Type AlternateWorkloadValidation
    $ini = ConvertTo-CoreCyclerIni -Phase $phase

    Assert-MatchText $ini '(?m)^stressTestProgram = YCRUNCHER\r?$'
    Assert-MatchText $ini '(?m)^\[yCruncher\]\r?$'
    Assert-MatchText $ini '(?m)^tests = SFTv4, FFTv4, N63\r?$'

    if ($ini -Match '(?m)^\[Prime95\]$') {
        throw('Did not expect a Prime95 section in a y-cruncher validation config.')
    }
}

It 'matches the Ryzen 5000 coarse discovery fixture' {
    $phase = New-CoreCyclerPhase -Name 'ryzen5000-coarse-discovery' -Type CoarseIsolatedDiscovery -RyzenGeneration Ryzen5000
    $ini = ConvertTo-CoreCyclerIni -Phase $phase
    $fixture = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'fixtures\ryzen5000-coarse-discovery.ini') -Raw

    Assert-SameNormalizedText -Actual $ini -Expected $fixture
}

It 'matches the Ryzen 9000 alternate validation fixture' {
    $phase = New-CoreCyclerPhase -Name 'ryzen9000-alt-validation' -Type AlternateWorkloadValidation -RyzenGeneration Ryzen9000
    $ini = ConvertTo-CoreCyclerIni -Phase $phase
    $fixture = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'fixtures\ryzen9000-alt-validation.ini') -Raw

    Assert-SameNormalizedText -Actual $ini -Expected $fixture
}

It 'exports generated INI text to an explicit output path' {
    $tempFile = Join-Path $env:TEMP ('CoreCyclerPhaseConfig-' + [Guid]::NewGuid().ToString() + '.ini')

    try {
        $phase = New-CoreCyclerPhase -Name 'export-smoke' -Type BaselineSanity
        $file = Export-CoreCyclerPhaseConfig -Phase $phase -OutputPath $tempFile

        Assert-True (Test-Path -LiteralPath $file.FullName)

        $content = Get-Content -LiteralPath $file.FullName -Raw
        Assert-MatchText $content '(?m)^# PhaseName = export-smoke\r?$'
    }
    finally {
        if (Test-Path -LiteralPath $tempFile) {
            Remove-Item -LiteralPath $tempFile -Force
        }
    }
}

Write-Host ('phase-config-generator.Tests.ps1: ' + $Script:TestCount + ' tests passed.')
