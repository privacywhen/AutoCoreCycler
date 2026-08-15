$repoPath = Join-Path $PSScriptRoot '..'
$modulePath = Join-Path $repoPath 'helpers\discovery-state.psm1'
$coreCyclerPath = Join-Path $repoPath 'script-corecycler.ps1'

Import-Module $modulePath -Force

function Import-CoreCyclerPersistenceFunction {
    param(
        [Parameter(Mandatory=$true)] [String] $Name
    )

    $tokens = $null
    $errors = $null
    $scriptAst = [System.Management.Automation.Language.Parser]::ParseFile($coreCyclerPath, [ref] $tokens, [ref] $errors)

    if ($errors.Count -gt 0) {
        throw 'Could not parse script-corecycler.ps1.'
    }

    $functionAst = $scriptAst.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $Name
    }, $true)

    if (!$functionAst) {
        throw ('Could not find function ' + $Name + ' in script-corecycler.ps1.')
    }

    $definition = $functionAst.Extent.Text -replace ('(?im)^function\s+' + [Regex]::Escape($Name) + '\b'), ('function global:' + $Name)
    Invoke-Expression $definition
}

function New-LegacyAutoModeFixture {
    param(
        [Parameter(Mandatory=$true)] [String] $Path,
        [Parameter(Mandatory=$false)] $DiscoveryStates
    )

    $content = @{
        fileTimestamp = [UInt64] 1
        lastCoreTested = 2
        logFileCoreCycler = 'corecycler.log'
        logFileStressTest = 'stress.log'
        voltageValues = @(-10)
        waitBeforeResume = 1
        schemaVersion = 2
        resultsFile = 'results.txt'
        iteration = 1
        resumeAttempts = 0
        remainingCoreOrder = @(2)
        coreStates = @{}
    }

    if ($null -ne $DiscoveryStates) {
        $content['discoveryStates'] = $DiscoveryStates
    }

    [System.IO.File]::WriteAllText($Path, (ConvertTo-Json $content -Depth 8))
}

Describe 'Discovery persistence integration contract' {
    BeforeEach {
        function Write-DebugText { param([String] $text) }
        function Write-VerboseText { param([String] $text) }
        function Exit-WithFatalError { param([String] $text) throw $text }

        Import-CoreCyclerPersistenceFunction -Name 'Get-ParsedAutoModeFile'
        Import-CoreCyclerPersistenceFunction -Name 'Get-AutoModeFileContent'
        Import-CoreCyclerPersistenceFunction -Name 'Save-AutoModeState'

        $Script:discoveryStateHelperModule = $modulePath
        $Script:useAutomaticTestModeWithResume = $true
        $Script:autoModeSchemaVersion = 2
        $Script:autoModeCurrentTestedCore = 2
        $Script:autoModeCurrentIteration = 1
        $Script:autoModeRemainingCoreOrder = @(2)
        $Script:autoModeResumeAttempts = 0
        $Script:autoModeResultsFileFullPath = (Join-Path $TestDrive 'results.txt')
        $Script:logFileFullPath = (Join-Path $TestDrive 'corecycler.log')
        $Script:stressTestLogFilePath = (Join-Path $TestDrive 'stress.log')
        $Script:settings = @{ AutomaticTestMode = @{ waitBeforeAutomaticResume = 1 } }
        $Script:voltageCurrentValues = @(-10)
        $Script:coreStates = @{}
        $Script:canUseFlushToDisk = $false
        $Script:autoModeFile = Join-Path $TestDrive '.automode'
        $Script:autoModeFileTemp = Join-Path $TestDrive '.automode-temp'
        $Script:autoModeFileBak = Join-Path $TestDrive '.automode-bak'
    }

    It 'writes and restores a complete discovery snapshot through the atomic automode document' {
        $state = New-DiscoveryCoreState -CoreNumber 2 -CurrentCandidate -18 -PlatformMinimum -30 -CandidateAttemptId 'candidate-core2--18' -StageAttemptIds @{ kagari = 'stage-kagari-18' }
        $state['lastObservedPass'] = -17
        $Script:discoveryCoreStates = @{ 2 = $state }

        Save-AutoModeState -coreNumber 2 -iterationNumber 1 -remainingCoreOrder @(2)

        $written = ConvertFrom-Json ([System.IO.File]::ReadAllText($autoModeFile))
        ($written | Get-Member -Name 'discoveryStates') | Should Not BeNullOrEmpty
        $written.discoveryStates.schemaVersion | Should Be 1

        $parsed = Get-ParsedAutoModeFile -filePath $autoModeFile
        $parsed['discoveryStates'][2]['candidateAttemptId'] | Should Be 'candidate-core2--18'
        $parsed['discoveryStates'][2]['lastObservedPass'] | Should Be -17
    }

    It 'rejects a torn discovery snapshot instead of returning a partial persisted state' {
        $tornState = [PSCustomObject]@{
            schemaVersion = 1
            states = [PSCustomObject]@{
                '2' = [PSCustomObject]@{
                    coreNumber = 2
                    currentCandidate = -18
                    platformMinimum = -30
                    stageAttemptIds = [PSCustomObject]@{ kagari = 'stage-kagari-18' }
                    lastObservedPass = -17
                    firstObservedFail = $null
                    discoveryCandidate = $null
                    resolution = $null
                }
            }
        }
        New-LegacyAutoModeFixture -Path $autoModeFile -DiscoveryStates $tornState

        { Get-ParsedAutoModeFile -filePath $autoModeFile } | Should Throw
    }

    It 'uses the validated backup generation when the primary discovery snapshot is torn' {
        $backupState = New-DiscoveryCoreState -CoreNumber 2 -CurrentCandidate -17 -PlatformMinimum -30 -CandidateAttemptId 'candidate-core2--17' -StageAttemptIds @{ kagari = 'stage-kagari-17' }
        New-LegacyAutoModeFixture -Path $autoModeFileBak -DiscoveryStates (ConvertTo-DiscoveryStateSnapshot -States @{ 2 = $backupState })

        $tornState = [PSCustomObject]@{
            schemaVersion = 1
            states = [PSCustomObject]@{
                '2' = [PSCustomObject]@{
                    coreNumber = 2
                    currentCandidate = -18
                    platformMinimum = -30
                    stageAttemptIds = [PSCustomObject]@{ kagari = 'stage-kagari-18' }
                    lastObservedPass = -17
                    firstObservedFail = $null
                    discoveryCandidate = $null
                    resolution = $null
                }
            }
        }
        New-LegacyAutoModeFixture -Path $autoModeFile -DiscoveryStates $tornState
        $Script:CoreFromAutoMode = 2

        $recovered = Get-AutoModeFileContent

        $recovered['discoveryStates'][2]['candidateAttemptId'] | Should Be 'candidate-core2--17'
    }

    It 'does not add a discovery field to legacy automatic-mode saves without discovery state' {
        $Script:discoveryCoreStates = @{}

        Save-AutoModeState -coreNumber 2 -iterationNumber 1 -remainingCoreOrder @(2)

        $written = ConvertFrom-Json ([System.IO.File]::ReadAllText($autoModeFile))
        ($written | Get-Member -Name 'discoveryStates') | Should BeNullOrEmpty
    }
}
