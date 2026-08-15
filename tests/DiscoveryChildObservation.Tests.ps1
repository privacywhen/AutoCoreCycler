$repoPath = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $repoPath 'helpers\discovery-child-launch.psm1') -Force

Describe 'Discovery child observation binding' {
    BeforeEach {
        $script:childScriptPath = Join-Path $TestDrive 'script-corecycler.ps1'
        $script:stageConfigPath = Join-Path $TestDrive 'stage-kagari.ini'
        $script:stageLogPath = Join-Path $TestDrive 'stage-kagari.log'
        $script:observedStart = [DateTime]::SpecifyKind(([DateTime]'2026-08-15T08:00:00'), [DateTimeKind]::Utc)
        Remove-Item -LiteralPath $stageLogPath -Recurse -Force -ErrorAction Ignore
        [System.IO.File]::WriteAllText($childScriptPath, '# synthetic child entry point')
        [System.IO.File]::WriteAllText($stageConfigPath, '[General]' + [Environment]::NewLine + 'stressTestProgram = ycruncher')
        $script:plan = New-DiscoveryStageChildLaunchPlan -ChildScriptPath $childScriptPath -StageConfigPath $stageConfigPath -CoreNumber 2 -Candidate -18 -CandidateAttemptId 'candidate-core2--18-a' -StageAttemptId 'stage-kagari-a' -WorkloadId 'kagari' -LogPath $stageLogPath
    }

    It 'binds a ready plan to externally observed child process identity without launching a process' {
        $readiness = Test-DiscoveryStageChildLaunchPlanReadiness -Plan $plan

        $observation = New-DiscoveryStageContextFromObservedChild -Plan $plan -ChildProcessId 4242 -StartedAt $observedStart

        $readiness.Ready | Should Be $true
        $observation.Observed | Should Be $true
        $observation.Reason | Should Be 'observed'
        $observation.Context.coreNumber | Should Be 2
        $observation.Context.candidate | Should Be -18
        $observation.Context.candidateAttemptId | Should Be 'candidate-core2--18-a'
        $observation.Context.stageAttemptId | Should Be 'stage-kagari-a'
        $observation.Context.workloadId | Should Be 'kagari'
        $observation.Context.configPath | Should Be ([System.IO.Path]::GetFullPath($stageConfigPath))
        $observation.Context.configFingerprint | Should Be $plan.Identity.configFingerprint
        $observation.Context.logPath | Should Be ([System.IO.Path]::GetFullPath($stageLogPath))
        $observation.Context.childProcessId | Should Be 4242
        $observation.Context.startedAt.ToUniversalTime() | Should Be ($observedStart.ToUniversalTime())
    }

    It 'binds observed identity after the stage log is created by the child boundary' {
        [System.IO.File]::WriteAllText($stageLogPath, 'child-created stage output')

        $observation = New-DiscoveryStageContextFromObservedChild -Plan $plan -ChildProcessId 4242 -StartedAt $observedStart

        $observation.Observed | Should Be $true
        $observation.Reason | Should Be 'observed'
        $observation.Context.logPath | Should Be ([System.IO.Path]::GetFullPath($stageLogPath))
    }

    It 'rejects observed child identity when config bytes changed after plan construction' {
        [System.IO.File]::AppendAllText($stageConfigPath, [Environment]::NewLine + 'runtimePerCore = 3m')

        $observation = New-DiscoveryStageContextFromObservedChild -Plan $plan -ChildProcessId 4242 -StartedAt $observedStart

        $observation.Observed | Should Be $false
        $observation.Reason | Should Be 'config_fingerprint_mismatch'
        $observation.Context | Should Be $null
    }

    It 'rejects config drift that occurs after a context fingerprint was captured' {
        $observation = New-DiscoveryStageContextFromObservedChild -Plan $plan -ChildProcessId 4242 -StartedAt $observedStart
        [System.IO.File]::AppendAllText($stageConfigPath, [Environment]::NewLine + 'runtimePerCore = 3m')
        $module = Get-Module | Where-Object { $_.Path -eq (Join-Path $repoPath 'helpers\discovery-child-launch.psm1') }

        $decision = & $module { param($Plan, $Context) Test-DiscoveryStageContextMatchesChildLaunchPlan -Plan $Plan -Context $Context } $plan $observation.Context

        $decision.Matches | Should Be $false
        $decision.Reason | Should Be 'config_fingerprint_mismatch'
    }

    It 'rejects invalid externally observed process identity without creating a context' {
        $invalidPid = New-DiscoveryStageContextFromObservedChild -Plan $plan -ChildProcessId 0 -StartedAt $observedStart
        $invalidStart = New-DiscoveryStageContextFromObservedChild -Plan $plan -ChildProcessId 4242 -StartedAt ([DateTime]::MinValue)

        $invalidPid.Observed | Should Be $false
        $invalidPid.Reason | Should Be 'invalid_observed_process_identity'
        $invalidPid.Context | Should Be $null
        $invalidStart.Observed | Should Be $false
        $invalidStart.Reason | Should Be 'invalid_observed_process_identity'
        $invalidStart.Context | Should Be $null
    }

    It 'rejects a non-UTC observed start time without creating a context' {
        $localStart = $observedStart.ToLocalTime()

        $observation = New-DiscoveryStageContextFromObservedChild -Plan $plan -ChildProcessId 4242 -StartedAt $localStart

        $observation.Observed | Should Be $false
        $observation.Reason | Should Be 'invalid_observed_process_identity'
        $observation.Context | Should Be $null
    }

    It 'fail-closes a malformed plan without fabricating observed context' {
        $malformedPlan = [PSCustomObject]@{}

        { New-DiscoveryStageContextFromObservedChild -Plan $malformedPlan -ChildProcessId 4242 -StartedAt $observedStart | Out-Null } | Should Not Throw
        $observation = New-DiscoveryStageContextFromObservedChild -Plan $malformedPlan -ChildProcessId 4242 -StartedAt $observedStart

        $observation.Observed | Should Be $false
        $observation.Reason | Should Be 'invalid_launch_plan'
        $observation.Context | Should Be $null
    }
}
