$repoPath = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $repoPath 'helpers\discovery-child-launch.psm1') -Force

Describe 'Discovery child launch plan' {
    BeforeEach {
        $script:childScriptPath = Join-Path $TestDrive 'script-corecycler.ps1'
        $script:stageConfigPath = Join-Path $TestDrive 'stage-kagari.ini'
        $script:stageLogPath = Join-Path $TestDrive 'stage-kagari.log'
        Remove-Item -LiteralPath $stageLogPath -Force -ErrorAction Ignore
        [System.IO.File]::WriteAllText($childScriptPath, '# synthetic child entry point')
        [System.IO.File]::WriteAllText($stageConfigPath, '[General]' + [Environment]::NewLine + 'stressTestProgram = ycruncher')
    }

    It 'fail-closes a malformed launch plan without throwing' {
        $malformedPlan = [PSCustomObject]@{}

        { Test-DiscoveryStageChildLaunchPlanReadiness -Plan $malformedPlan | Out-Null } | Should Not Throw
        $readiness = Test-DiscoveryStageChildLaunchPlanReadiness -Plan $malformedPlan
        $readiness.Ready | Should Be $false
        $readiness.Reason | Should Be 'invalid_launch_plan'
    }

    It 'fail-closes missing or malformed launch-plan structures without throwing' {
        $validPlan = New-DiscoveryStageChildLaunchPlan -ChildScriptPath $childScriptPath -StageConfigPath $stageConfigPath -CoreNumber 2 -Candidate -18 -CandidateAttemptId 'candidate-core2--18-a' -StageAttemptId 'stage-kagari-a' -WorkloadId 'kagari' -LogPath $stageLogPath
        $missingArgumentList = [PSCustomObject]@{ FilePath = 'powershell.exe' }
        $malformedIdentity = [PSCustomObject]@{ FilePath = $validPlan.FilePath; ArgumentList = $validPlan.ArgumentList; WorkingDirectory = $validPlan.WorkingDirectory; Identity = @{}; RequiresObservedProcessIdentity = $true }
        $malformedArguments = [PSCustomObject]@{ FilePath = $validPlan.FilePath; ArgumentList = @('-File'); WorkingDirectory = $validPlan.WorkingDirectory; Identity = $validPlan.Identity; RequiresObservedProcessIdentity = $true }

        foreach ($malformedPlan in @($missingArgumentList, $malformedIdentity, $malformedArguments)) {
            { Test-DiscoveryStageChildLaunchPlanReadiness -Plan $malformedPlan | Out-Null } | Should Not Throw
            $readiness = Test-DiscoveryStageChildLaunchPlanReadiness -Plan $malformedPlan
            $readiness.Ready | Should Be $false
            $readiness.Reason | Should Be 'invalid_launch_plan'
        }
    }

    It 'fail-closes an identity containing an invalid config path without throwing' {
        $validPlan = New-DiscoveryStageChildLaunchPlan -ChildScriptPath $childScriptPath -StageConfigPath $stageConfigPath -CoreNumber 2 -Candidate -18 -CandidateAttemptId 'candidate-core2--18-a' -StageAttemptId 'stage-kagari-a' -WorkloadId 'kagari' -LogPath $stageLogPath
        $invalidIdentity = @{}
        foreach ($key in $validPlan.Identity.Keys) { $invalidIdentity[$key] = $validPlan.Identity[$key] }
        $invalidIdentity['configPath'] = ([Char] 0).ToString()
        $invalidPathPlan = [PSCustomObject]@{ FilePath = $validPlan.FilePath; ArgumentList = $validPlan.ArgumentList; WorkingDirectory = $validPlan.WorkingDirectory; Identity = $invalidIdentity; RequiresObservedProcessIdentity = $true }

        { Test-DiscoveryStageChildLaunchPlanReadiness -Plan $invalidPathPlan | Out-Null } | Should Not Throw
        $readiness = Test-DiscoveryStageChildLaunchPlanReadiness -Plan $invalidPathPlan
        $readiness.Ready | Should Be $false
        $readiness.Reason | Should Be 'invalid_launch_plan'
    }

    It 'fail-closes a non-scalar FilePath without returning ready' {
        $validPlan = New-DiscoveryStageChildLaunchPlan -ChildScriptPath $childScriptPath -StageConfigPath $stageConfigPath -CoreNumber 2 -Candidate -18 -CandidateAttemptId 'candidate-core2--18-a' -StageAttemptId 'stage-kagari-a' -WorkloadId 'kagari' -LogPath $stageLogPath
        $invalidFilePathPlan = [PSCustomObject]@{ FilePath = @(); ArgumentList = $validPlan.ArgumentList; WorkingDirectory = $validPlan.WorkingDirectory; Identity = $validPlan.Identity; RequiresObservedProcessIdentity = $true }

        { Test-DiscoveryStageChildLaunchPlanReadiness -Plan $invalidFilePathPlan | Out-Null } | Should Not Throw
        $readiness = Test-DiscoveryStageChildLaunchPlanReadiness -Plan $invalidFilePathPlan
        $readiness.Ready | Should Be $false
        $readiness.Reason | Should Be 'invalid_launch_plan'
    }

    It 'reports a newly built child plan ready immediately before launch' {
        $plan = New-DiscoveryStageChildLaunchPlan -ChildScriptPath $childScriptPath -StageConfigPath $stageConfigPath -CoreNumber 2 -Candidate -18 -CandidateAttemptId 'candidate-core2--18-a' -StageAttemptId 'stage-kagari-a' -WorkloadId 'kagari' -LogPath $stageLogPath

        $readiness = Test-DiscoveryStageChildLaunchPlanReadiness -Plan $plan

        $readiness.Ready | Should Be $true
        $readiness.Reason | Should Be 'ready'
    }

    It 'rejects a launch plan when the child script disappears after planning' {
        $plan = New-DiscoveryStageChildLaunchPlan -ChildScriptPath $childScriptPath -StageConfigPath $stageConfigPath -CoreNumber 2 -Candidate -18 -CandidateAttemptId 'candidate-core2--18-a' -StageAttemptId 'stage-kagari-a' -WorkloadId 'kagari' -LogPath $stageLogPath
        Remove-Item -LiteralPath $childScriptPath -Force

        $readiness = Test-DiscoveryStageChildLaunchPlanReadiness -Plan $plan

        $readiness.Ready | Should Be $false
        $readiness.Reason | Should Be 'child_script_unavailable'
    }

    It 'rejects a launch plan when a log-path directory appears after planning' {
        $plan = New-DiscoveryStageChildLaunchPlan -ChildScriptPath $childScriptPath -StageConfigPath $stageConfigPath -CoreNumber 2 -Candidate -18 -CandidateAttemptId 'candidate-core2--18-a' -StageAttemptId 'stage-kagari-a' -WorkloadId 'kagari' -LogPath $stageLogPath
        New-Item -ItemType Directory -Path $stageLogPath | Out-Null

        $readiness = Test-DiscoveryStageChildLaunchPlanReadiness -Plan $plan

        $readiness.Ready | Should Be $false
        $readiness.Reason | Should Be 'stage_log_not_fresh'
    }

    It 'rejects a launch plan when its log target appears after planning' {
        $plan = New-DiscoveryStageChildLaunchPlan -ChildScriptPath $childScriptPath -StageConfigPath $stageConfigPath -CoreNumber 2 -Candidate -18 -CandidateAttemptId 'candidate-core2--18-a' -StageAttemptId 'stage-kagari-a' -WorkloadId 'kagari' -LogPath $stageLogPath
        [System.IO.File]::WriteAllText($stageLogPath, 'unexpected stale output')

        $readiness = Test-DiscoveryStageChildLaunchPlanReadiness -Plan $plan

        $readiness.Ready | Should Be $false
        $readiness.Reason | Should Be 'stage_log_not_fresh'
    }

    It 'rejects a launch plan whose stage config bytes changed after planning' {
        $plan = New-DiscoveryStageChildLaunchPlan -ChildScriptPath $childScriptPath -StageConfigPath $stageConfigPath -CoreNumber 2 -Candidate -18 -CandidateAttemptId 'candidate-core2--18-a' -StageAttemptId 'stage-kagari-a' -WorkloadId 'kagari' -LogPath $stageLogPath
        [System.IO.File]::WriteAllText($stageConfigPath, '[General]' + [Environment]::NewLine + 'stressTestProgram = kagari')

        $readiness = Test-DiscoveryStageChildLaunchPlanReadiness -Plan $plan

        $readiness.Ready | Should Be $false
        $readiness.Reason | Should Be 'config_fingerprint_mismatch'
    }

    It 'keeps a stage config path containing spaces as one argument token' {
        $directoryWithSpaces = Join-Path $TestDrive 'stage configs with spaces'
        New-Item -ItemType Directory -Path $directoryWithSpaces | Out-Null
        $configWithSpaces = Join-Path $directoryWithSpaces 'kagari stage.ini'
        [System.IO.File]::WriteAllText($configWithSpaces, '[General]')

        $plan = New-DiscoveryStageChildLaunchPlan -ChildScriptPath $childScriptPath -StageConfigPath $configWithSpaces -CoreNumber 2 -Candidate -18 -CandidateAttemptId 'candidate-core2--18-a' -StageAttemptId 'stage-kagari-a' -WorkloadId 'kagari' -LogPath $stageLogPath

        $configArgumentIndex = [Array]::IndexOf([String[]] $plan.ArgumentList, '-ConfigPath')
        $plan.ArgumentList[$configArgumentIndex + 1] | Should Be ([System.IO.Path]::GetFullPath($configWithSpaces))
    }

    It 'rejects a missing stage config without creating a fallback root config.ini' {
        $missingStageConfigPath = Join-Path $TestDrive 'missing-stage.ini'
        $rootConfigPath = Join-Path $TestDrive 'config.ini'
        Remove-Item -LiteralPath $rootConfigPath -Force -ErrorAction Ignore

        { New-DiscoveryStageChildLaunchPlan -ChildScriptPath $childScriptPath -StageConfigPath $missingStageConfigPath -CoreNumber 2 -Candidate -18 -CandidateAttemptId 'candidate-core2--18-a' -StageAttemptId 'stage-kagari-a' -WorkloadId 'kagari' -LogPath $stageLogPath } | Should Throw 'Discovery child stage config path does not exist or is not a file.'
        (Test-Path -LiteralPath $missingStageConfigPath) | Should Be $false
        (Test-Path -LiteralPath $rootConfigPath) | Should Be $false
    }

    It 'rejects the repository config.ini as a stage input' {
        $rootConfigPath = Join-Path $TestDrive 'config.ini'
        [System.IO.File]::WriteAllText($rootConfigPath, '[General]')

        { New-DiscoveryStageChildLaunchPlan -ChildScriptPath $childScriptPath -StageConfigPath $rootConfigPath -CoreNumber 2 -Candidate -18 -CandidateAttemptId 'candidate-core2--18-a' -StageAttemptId 'stage-kagari-a' -WorkloadId 'kagari' -LogPath $stageLogPath } | Should Throw 'Discovery child stage config must not be the repository config.ini.'
    }

    It 'rejects a directory at the stage log target to preserve fresh evidence' {
        New-Item -ItemType Directory -Path $stageLogPath | Out-Null

        { New-DiscoveryStageChildLaunchPlan -ChildScriptPath $childScriptPath -StageConfigPath $stageConfigPath -CoreNumber 2 -Candidate -18 -CandidateAttemptId 'candidate-core2--18-a' -StageAttemptId 'stage-kagari-a' -WorkloadId 'kagari' -LogPath $stageLogPath } | Should Throw 'Discovery child stage log path must be fresh and not already exist.'
    }

    It 'rejects a pre-existing stage log target to prevent stale evidence reuse' {
        [System.IO.File]::WriteAllText($stageLogPath, 'stale prior-stage log')

        { New-DiscoveryStageChildLaunchPlan -ChildScriptPath $childScriptPath -StageConfigPath $stageConfigPath -CoreNumber 2 -Candidate -18 -CandidateAttemptId 'candidate-core2--18-a' -StageAttemptId 'stage-kagari-a' -WorkloadId 'kagari' -LogPath $stageLogPath } | Should Throw 'Discovery child stage log path must be fresh and not already exist.'
    }

    It 'builds a non-executing fresh-child plan with explicit stage config and identity template' {
        $plan = New-DiscoveryStageChildLaunchPlan -ChildScriptPath $childScriptPath -StageConfigPath $stageConfigPath -CoreNumber 2 -Candidate -18 -CandidateAttemptId 'candidate-core2--18-a' -StageAttemptId 'stage-kagari-a' -WorkloadId 'kagari' -LogPath $stageLogPath

        $plan.FilePath | Should Be 'powershell.exe'
        @($plan.ArgumentList) | Should Be @('-ExecutionPolicy', 'Bypass', '-File', [System.IO.Path]::GetFullPath($childScriptPath), '-ConfigPath', [System.IO.Path]::GetFullPath($stageConfigPath))
        $plan.WorkingDirectory | Should Be ([System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($childScriptPath)))
        $plan.Identity.coreNumber | Should Be 2
        $plan.Identity.candidate | Should Be -18
        $plan.Identity.candidateAttemptId | Should Be 'candidate-core2--18-a'
        $plan.Identity.stageAttemptId | Should Be 'stage-kagari-a'
        $plan.Identity.workloadId | Should Be 'kagari'
        $plan.Identity.logPath | Should Be ([System.IO.Path]::GetFullPath($stageLogPath))
        $plan.Identity.configPath | Should Be ([System.IO.Path]::GetFullPath($stageConfigPath))
        $expectedFingerprintBytes = [System.Security.Cryptography.SHA256]::Create().ComputeHash([System.IO.File]::ReadAllBytes($stageConfigPath))
        $expectedFingerprint = ([BitConverter]::ToString($expectedFingerprintBytes)).Replace('-', '').ToLowerInvariant()
        $plan.Identity.configFingerprint | Should Be $expectedFingerprint
        $plan.RequiresObservedProcessIdentity | Should Be $true
    }
}
