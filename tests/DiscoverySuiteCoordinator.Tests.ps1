$repoPath = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $repoPath 'helpers\discovery-suite.psm1') -Force
Import-Module (Join-Path $repoPath 'helpers\discovery-state.psm1') -Force
Import-Module (Join-Path $repoPath 'helpers\discovery-stage.psm1') -Force

Describe 'Discovery suite coordinator' {
    BeforeEach {
        $script:workloads = @('kagari', 'prime95-720k')
        $script:stageAttemptIds = @{
            'kagari'       = 'stage-kagari-a'
            'prime95-720k' = 'stage-prime95-720k-a'
        }
        $script:state = New-DiscoveryCoreState -CoreNumber 2 -CurrentCandidate -18 -PlatformMinimum -30 -CandidateAttemptId 'candidate-core2--18-a' -StageAttemptIds $stageAttemptIds
        $state.attemptStatus = 'APPLIED_VERIFIED'

        $configPath = Join-Path $TestDrive 'kagari-stage.ini'
        $logPath = Join-Path $TestDrive 'kagari-stage.log'
        [System.IO.File]::WriteAllText($configPath, '[General]' + [Environment]::NewLine + 'stressTestProgram = ycruncher')
        [System.IO.File]::WriteAllText($logPath, 'fresh-kagari-log')

        $script:context = New-DiscoveryStageContext -CoreNumber 2 -Candidate -18 -CandidateAttemptId 'candidate-core2--18-a' -StageAttemptId 'stage-kagari-a' -WorkloadId 'kagari' -ConfigPath $configPath -LogPath $logPath -ChildProcessId 4242 -StartedAt ([DateTime]'2026-08-15T07:10:00Z')
        $script:matchingResult = @{
            candidateAttemptId                    = 'candidate-core2--18-a'
            stageAttemptId                        = 'stage-kagari-a'
            workloadId                            = 'kagari'
            coreNumber                            = 2
            candidate                             = -18
            configFingerprint                     = $context.configFingerprint
            logPath                               = $logPath
            childProcessId                        = 4242
            startedAt                             = [DateTime]'2026-08-15T07:10:00Z'
            outcome                               = 'PASS'
            childExited                           = $true
            expectedStressProcessCleanupVerified  = $true
        }
    }

    It 'rejects an out-of-order final stage even when its evidence is otherwise valid' {
        $configPath = Join-Path $TestDrive 'prime95-stage.ini'
        $logPath = Join-Path $TestDrive 'prime95-stage.log'
        [System.IO.File]::WriteAllText($configPath, '[General]' + [Environment]::NewLine + 'stressTestProgram = PRIME95')
        [System.IO.File]::WriteAllText($logPath, 'fresh-prime95-log')
        $finalContext = New-DiscoveryStageContext -CoreNumber 2 -Candidate -18 -CandidateAttemptId 'candidate-core2--18-a' -StageAttemptId 'stage-prime95-720k-a' -WorkloadId 'prime95-720k' -ConfigPath $configPath -LogPath $logPath -ChildProcessId 4243 -StartedAt ([DateTime]'2026-08-15T07:11:00Z')
        $finalResult = @{} + $matchingResult
        $finalResult.stageAttemptId = 'stage-prime95-720k-a'
        $finalResult.workloadId = 'prime95-720k'
        $finalResult.configFingerprint = $finalContext.configFingerprint
        $finalResult.logPath = $logPath
        $finalResult.childProcessId = 4243
        $finalResult.startedAt = [DateTime]'2026-08-15T07:11:00Z'

        $decision = Resolve-DiscoverySuiteStage -State $state -Context $finalContext -Result $finalResult -RequiredWorkloadIds $workloads -CompletedWorkloadIds @() -CurrentStageIndex 1

        $decision.Accepted | Should Be $false
        $decision.Reason | Should Be 'suite_progress_mismatch'
        $decision.Disposition | Should Be 'REJECTED'
        $decision.State.currentCandidate | Should Be -18
    }

    It 'rejects coercible lifecycle values instead of treating them as verified cleanup' {
        $coercibleResult = @{} + $matchingResult
        $coercibleResult.childExited = 'True'
        $coercibleResult.expectedStressProcessCleanupVerified = 1

        $decision = Resolve-DiscoverySuiteStage -State $state -Context $context -Result $coercibleResult -RequiredWorkloadIds $workloads -CompletedWorkloadIds @() -CurrentStageIndex 0

        $decision.Accepted | Should Be $false
        $decision.Reason | Should Be 'child_lifecycle_unverified'
        $decision.Disposition | Should Be 'REJECTED'
    }

    It 'does not advance after a pass without verified child exit and cleanup' {
        $uncleanResult = @{} + $matchingResult
        $uncleanResult.expectedStressProcessCleanupVerified = $false

        $decision = Resolve-DiscoverySuiteStage -State $state -Context $context -Result $uncleanResult -RequiredWorkloadIds $workloads -CompletedWorkloadIds @() -CurrentStageIndex 0

        $decision.Accepted | Should Be $false
        $decision.Reason | Should Be 'child_lifecycle_unverified'
        $decision.Disposition | Should Be 'REJECTED'
        $decision.NextStageIndex | Should Be 0
        @($decision.CompletedWorkloadIds).Count | Should Be 0
    }

    It 'records infrastructure-invalid evidence without advancing or changing the candidate' {
        $invalidResult = @{} + $matchingResult
        $invalidResult.outcome = 'INFRASTRUCTURE_INVALID'

        $decision = Resolve-DiscoverySuiteStage -State $state -Context $context -Result $invalidResult -RequiredWorkloadIds $workloads -CompletedWorkloadIds @() -CurrentStageIndex 0

        $decision.Accepted | Should Be $true
        $decision.Disposition | Should Be 'RETRY_REQUIRES_FRESH_STAGE_IDENTITY'
        $decision.RequiresFreshStageIdentity | Should Be $true
        $decision.Reason | Should Be 'infrastructure_invalid'
        $decision.NextStageIndex | Should Be 0
        @($decision.CompletedWorkloadIds).Count | Should Be 0
        $decision.State.currentCandidate | Should Be -18
        $decision.State.resolution | Should Be $null
    }

    It 'quarantines ambiguous stage evidence without advancing the suite' {
        $ambiguousResult = @{} + $matchingResult
        $ambiguousResult.outcome = 'AMBIGUOUS_FAIL'

        $decision = Resolve-DiscoverySuiteStage -State $state -Context $context -Result $ambiguousResult -RequiredWorkloadIds $workloads -CompletedWorkloadIds @() -CurrentStageIndex 0

        $decision.Accepted | Should Be $true
        $decision.Disposition | Should Be 'CANDIDATE_EVIDENCE_RECORDED'
        $decision.NextStageIndex | Should Be 0
        $decision.NextWorkloadId | Should Be $null
        @($decision.CompletedWorkloadIds).Count | Should Be 0
        $decision.State.resolution | Should Be 'QUARANTINED_AMBIGUOUS'
    }

    It 'fails fast on an attributable stage failure without advancing the suite' {
        $failedResult = @{} + $matchingResult
        $failedResult.outcome = 'ATTRIBUTED_FAIL'

        $decision = Resolve-DiscoverySuiteStage -State $state -Context $context -Result $failedResult -RequiredWorkloadIds $workloads -CompletedWorkloadIds @() -CurrentStageIndex 0

        $decision.Accepted | Should Be $true
        $decision.Disposition | Should Be 'CANDIDATE_EVIDENCE_RECORDED'
        $decision.NextStageIndex | Should Be 0
        $decision.NextWorkloadId | Should Be $null
        @($decision.CompletedWorkloadIds).Count | Should Be 0
        $decision.State.firstObservedFail | Should Be -18
        $decision.State.resolution | Should Be 'NO_VALID_BASELINE'
    }

    It 'converts the final ordered stage pass into one complete-suite observed pass' {
        $configPath = Join-Path $TestDrive 'prime95-stage.ini'
        $logPath = Join-Path $TestDrive 'prime95-stage.log'
        [System.IO.File]::WriteAllText($configPath, '[General]' + [Environment]::NewLine + 'stressTestProgram = PRIME95')
        [System.IO.File]::WriteAllText($logPath, 'fresh-prime95-log')
        $finalContext = New-DiscoveryStageContext -CoreNumber 2 -Candidate -18 -CandidateAttemptId 'candidate-core2--18-a' -StageAttemptId 'stage-prime95-720k-a' -WorkloadId 'prime95-720k' -ConfigPath $configPath -LogPath $logPath -ChildProcessId 4243 -StartedAt ([DateTime]'2026-08-15T07:11:00Z')
        $finalResult = @{} + $matchingResult
        $finalResult.stageAttemptId = 'stage-prime95-720k-a'
        $finalResult.workloadId = 'prime95-720k'
        $finalResult.configFingerprint = $finalContext.configFingerprint
        $finalResult.logPath = $logPath
        $finalResult.childProcessId = 4243
        $finalResult.startedAt = [DateTime]'2026-08-15T07:11:00Z'

        $decision = Resolve-DiscoverySuiteStage -State $state -Context $finalContext -Result $finalResult -RequiredWorkloadIds $workloads -CompletedWorkloadIds @('kagari') -CurrentStageIndex 1

        $decision.Accepted | Should Be $true
        $decision.Disposition | Should Be 'CANDIDATE_EVIDENCE_RECORDED'
        @($decision.CompletedWorkloadIds) | Should Be @('kagari', 'prime95-720k')
        $decision.State.lastObservedPass | Should Be -18
        $decision.State.currentCandidate | Should Be -19
        $decision.State.resolution | Should Be $null
    }

    It 'advances from a validated nonterminal pass to the next required workload' {
        $decision = Resolve-DiscoverySuiteStage -State $state -Context $context -Result $matchingResult -RequiredWorkloadIds $workloads -CompletedWorkloadIds @() -CurrentStageIndex 0

        $decision.Accepted | Should Be $true
        $decision.Disposition | Should Be 'ADVANCE_STAGE'
        $decision.NextStageIndex | Should Be 1
        $decision.NextWorkloadId | Should Be 'prime95-720k'
        @($decision.CompletedWorkloadIds) | Should Be @('kagari')
        $decision.State.currentCandidate | Should Be -18
        $decision.State.lastObservedPass | Should Be $null
    }
}
