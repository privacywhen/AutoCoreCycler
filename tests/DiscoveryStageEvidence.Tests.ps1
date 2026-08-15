$modulePath = Join-Path (Split-Path -Parent $PSScriptRoot) 'helpers\discovery-stage.psm1'
Import-Module $modulePath -Force

Describe 'Discovery stage evidence identity' {
    BeforeEach {
        $configPath = Join-Path $TestDrive 'stage.ini'
        $logPath = Join-Path $TestDrive 'stage.log'
        [System.IO.File]::WriteAllText($configPath, '[General]' + [Environment]::NewLine + 'stressTestProgram = PRIME95')
        [System.IO.File]::WriteAllText($logPath, 'fresh-stage-log')

        $script:context = New-DiscoveryStageContext -CoreNumber 2 -Candidate -18 -CandidateAttemptId 'candidate-core2--18-a' -StageAttemptId 'stage-prime95-avx2-a' -WorkloadId 'prime95-avx2-720k' -ConfigPath $configPath -LogPath $logPath -ChildProcessId 4242 -StartedAt ([DateTime]'2026-08-15T06:45:00Z')
        $script:matchingResult = @{
            candidateAttemptId = 'candidate-core2--18-a'
            stageAttemptId     = 'stage-prime95-avx2-a'
            workloadId         = 'prime95-avx2-720k'
            coreNumber         = 2
            candidate          = -18
            configFingerprint  = $context.configFingerprint
            logPath            = $logPath
            childProcessId     = 4242
            startedAt          = [DateTime]'2026-08-15T06:45:00Z'
            outcome            = 'PASS'
        }
    }

    It 'accepts only a complete result matching the active stage context' {
        $decision = Test-DiscoveryStageResult -Context $context -Result $matchingResult

        $decision.Accepted | Should Be $true
        $decision.Reason | Should Be 'accepted'
    }

    It 'rejects stale candidate identity before result interpretation' {
        $staleResult = @{} + $matchingResult
        $staleResult.candidateAttemptId = 'candidate-core2--17-old'

        $decision = Test-DiscoveryStageResult -Context $context -Result $staleResult

        $decision.Accepted | Should Be $false
        $decision.Reason | Should Be 'stale_candidate_attempt'
    }

    It 'rejects results if the stage config bytes changed after the context was created' {
        [System.IO.File]::AppendAllText($context.configPath, [Environment]::NewLine + 'runtimePerCore = 3m')

        $decision = Test-DiscoveryStageResult -Context $context -Result $matchingResult

        $decision.Accepted | Should Be $false
        $decision.Reason | Should Be 'config_fingerprint_mismatch'
    }

    It 'rejects missing core or candidate identity instead of coercing them to zero' {
        $missingCoreResult = @{} + $matchingResult
        $missingCoreResult.Remove('coreNumber')
        $coreDecision = Test-DiscoveryStageResult -Context $context -Result $missingCoreResult
        $coreDecision.Accepted | Should Be $false
        $coreDecision.Reason | Should Be 'missing_core_identity'

        $missingCandidateResult = @{} + $matchingResult
        $missingCandidateResult.Remove('candidate')
        $candidateDecision = Test-DiscoveryStageResult -Context $context -Result $missingCandidateResult
        $candidateDecision.Accepted | Should Be $false
        $candidateDecision.Reason | Should Be 'missing_candidate_value'
    }

    It 'rejects a deleted active config as infrastructure-invalid instead of throwing' {
        Remove-Item -LiteralPath $context.configPath -Force

        { $script:decision = Test-DiscoveryStageResult -Context $context -Result $matchingResult } | Should Not Throw
        $decision.Accepted | Should Be $false
        $decision.Reason | Should Be 'config_fingerprint_unavailable'
    }

    It 'rejects missing or mismatched stage/process/time identity as infrastructure-invalid' {
        $missingStageResult = @{} + $matchingResult
        $missingStageResult.Remove('stageAttemptId')
        $missingDecision = Test-DiscoveryStageResult -Context $context -Result $missingStageResult
        $missingDecision.Accepted | Should Be $false
        $missingDecision.Reason | Should Be 'missing_stage_identity'

        $wrongProcessResult = @{} + $matchingResult
        $wrongProcessResult.childProcessId = 4243
        $processDecision = Test-DiscoveryStageResult -Context $context -Result $wrongProcessResult
        $processDecision.Accepted | Should Be $false
        $processDecision.Reason | Should Be 'stage_process_mismatch'

        $wrongTimeResult = @{} + $matchingResult
        $wrongTimeResult.startedAt = [DateTime]'2026-08-15T06:45:01Z'
        $timeDecision = Test-DiscoveryStageResult -Context $context -Result $wrongTimeResult
        $timeDecision.Accepted | Should Be $false
        $timeDecision.Reason | Should Be 'stage_start_mismatch'
    }
}
