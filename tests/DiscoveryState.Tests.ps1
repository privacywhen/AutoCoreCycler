$modulePath = Join-Path $PSScriptRoot '..\helpers\discovery-state.psm1'
Import-Module $modulePath -Force

Describe 'Discovery state transitions' {
    It 'advances exactly one negative CO step after a verified complete-suite pass' {
        $state = New-DiscoveryCoreState -CoreNumber 2 -CurrentCandidate -17 -PlatformMinimum -30 -CandidateAttemptId 'candidate-core2--17' -StageAttemptIds @{
            kagari = 'stage-kagari-17'
            sse    = 'stage-sse-17'
        }

        $result = Resolve-DiscoveryEvidence -State $state -Evidence @{
            Classification      = 'OBSERVED_PASS'
            Candidate           = -17
            CandidateAttemptId  = 'candidate-core2--17'
            ApplicationVerified = $true
            CompleteSuite       = $true
            StageAttemptIds     = @{
                kagari = 'stage-kagari-17'
                sse    = 'stage-sse-17'
            }
        }

        $result.Accepted | Should Be $true
        $result.State['lastObservedPass'] | Should Be -17
        $result.State['currentCandidate'] | Should Be -18
        $result.State['resolution'] | Should BeNullOrEmpty
        (Test-DiscoveryCoreCanBeScheduled -State $result.State) | Should Be $true
    }

    It 'does not advance after a partial-suite pass' {
        $state = New-DiscoveryCoreState -CoreNumber 2 -CurrentCandidate -17 -PlatformMinimum -30 -CandidateAttemptId 'candidate-core2--17' -StageAttemptIds @{
            kagari = 'stage-kagari-17'
            sse    = 'stage-sse-17'
        }

        $result = Resolve-DiscoveryEvidence -State $state -Evidence @{
            Classification      = 'OBSERVED_PASS'
            Candidate           = -17
            CandidateAttemptId  = 'candidate-core2--17'
            ApplicationVerified = $true
            CompleteSuite       = $false
            StageAttemptIds     = @{
                kagari = 'stage-kagari-17'
                sse    = 'stage-sse-17'
            }
        }

        $result.Accepted | Should Be $false
        $result.Reason | Should Be 'suite_incomplete'
        $result.State['lastObservedPass'] | Should BeNullOrEmpty
        $result.State['currentCandidate'] | Should Be -17
    }

    It 'resolves an attributable failure to the previous complete-suite pass' {
        $state = New-DiscoveryCoreState -CoreNumber 2 -CurrentCandidate -18 -PlatformMinimum -30 -CandidateAttemptId 'candidate-core2--18' -StageAttemptIds @{
            kagari = 'stage-kagari-18'
        }
        $state['lastObservedPass'] = -17

        $result = Resolve-DiscoveryEvidence -State $state -Evidence @{
            Classification      = 'ATTRIBUTED_FAIL'
            Candidate           = -18
            CandidateAttemptId  = 'candidate-core2--18'
            ApplicationVerified = $true
            CompleteSuite       = $false
            StageAttemptIds     = @{ kagari = 'stage-kagari-18' }
        }

        $result.Accepted | Should Be $true
        $result.State['firstObservedFail'] | Should Be -18
        $result.State['discoveryCandidate'] | Should Be -17
        $result.State['resolution'] | Should Be 'DISCOVERY_CANDIDATE'
        (Test-DiscoveryCoreCanBeScheduled -State $result.State) | Should Be $false
    }


    It 'resolves no-valid-baseline and platform-minimum terminal outcomes' {
        $noBaselineState = New-DiscoveryCoreState -CoreNumber 2 -CurrentCandidate -18 -PlatformMinimum -30 -CandidateAttemptId 'candidate-core2--18' -StageAttemptIds @{ kagari = 'stage-kagari-18' }
        $noBaseline = Resolve-DiscoveryEvidence -State $noBaselineState -Evidence @{
            Classification      = 'ATTRIBUTED_FAIL'
            Candidate           = -18
            CandidateAttemptId  = 'candidate-core2--18'
            ApplicationVerified = $true
            CompleteSuite       = $false
            StageAttemptIds     = @{ kagari = 'stage-kagari-18' }
        }

        $noBaseline.State['firstObservedFail'] | Should Be -18
        $noBaseline.State['resolution'] | Should Be 'NO_VALID_BASELINE'
        (Test-DiscoveryCoreCanBeScheduled -State $noBaseline.State) | Should Be $false

        $minimumState = New-DiscoveryCoreState -CoreNumber 2 -CurrentCandidate -30 -PlatformMinimum -30 -CandidateAttemptId 'candidate-core2--30' -StageAttemptIds @{ kagari = 'stage-kagari-30' }
        $atMinimum = Resolve-DiscoveryEvidence -State $minimumState -Evidence @{
            Classification      = 'OBSERVED_PASS'
            Candidate           = -30
            CandidateAttemptId  = 'candidate-core2--30'
            ApplicationVerified = $true
            CompleteSuite       = $true
            StageAttemptIds     = @{ kagari = 'stage-kagari-30' }
        }

        $atMinimum.Accepted | Should Be $true
        $atMinimum.State['lastObservedPass'] | Should Be -30
        $atMinimum.State['resolution'] | Should Be 'PLATFORM_LIMIT_REACHED'
        $atMinimum.State['currentCandidate'] | Should Be -30
        (Test-DiscoveryCoreCanBeScheduled -State $atMinimum.State) | Should Be $false
    }


    It 'quarantines ambiguous failure and leaves infrastructure-invalid evidence boundary-free' {
        $ambiguousState = New-DiscoveryCoreState -CoreNumber 2 -CurrentCandidate -18 -PlatformMinimum -30 -CandidateAttemptId 'candidate-core2--18' -StageAttemptIds @{ kagari = 'stage-kagari-18' }
        $ambiguousState['lastObservedPass'] = -17
        $ambiguous = Resolve-DiscoveryEvidence -State $ambiguousState -Evidence @{
            Classification      = 'AMBIGUOUS_FAIL'
            Candidate           = -18
            CandidateAttemptId  = 'candidate-core2--18'
            ApplicationVerified = $true
            CompleteSuite       = $false
            StageAttemptIds     = @{ kagari = 'stage-kagari-18' }
        }

        $ambiguous.Accepted | Should Be $true
        $ambiguous.State['firstObservedFail'] | Should BeNullOrEmpty
        $ambiguous.State['lastObservedPass'] | Should Be -17
        $ambiguous.State['resolution'] | Should Be 'QUARANTINED_AMBIGUOUS'
        (Test-DiscoveryCoreCanBeScheduled -State $ambiguous.State) | Should Be $false

        $infrastructureState = New-DiscoveryCoreState -CoreNumber 2 -CurrentCandidate -18 -PlatformMinimum -30 -CandidateAttemptId 'candidate-core2--18' -StageAttemptIds @{ kagari = 'stage-kagari-18' }
        $infrastructureState['lastObservedPass'] = -17
        $infrastructure = Resolve-DiscoveryEvidence -State $infrastructureState -Evidence @{
            Classification      = 'INFRASTRUCTURE_INVALID'
            Candidate           = -18
            CandidateAttemptId  = 'candidate-core2--18'
            ApplicationVerified = $true
            CompleteSuite       = $false
            StageAttemptIds     = @{ kagari = 'stage-kagari-18' }
        }

        $infrastructure.Accepted | Should Be $true
        $infrastructure.Reason | Should Be 'infrastructure_invalid'
        $infrastructure.State['firstObservedFail'] | Should BeNullOrEmpty
        $infrastructure.State['lastObservedPass'] | Should Be -17
        $infrastructure.State['resolution'] | Should BeNullOrEmpty
        (Test-DiscoveryCoreCanBeScheduled -State $infrastructure.State) | Should Be $true
    }


    It 'requires verified application and keeps candidate and stage identities distinct' {
        $state = New-DiscoveryCoreState -CoreNumber 2 -CurrentCandidate -17 -PlatformMinimum -30 -CandidateAttemptId 'candidate-core2--17' -StageAttemptIds @{
            kagari = 'stage-kagari-17'
            sse    = 'stage-sse-17'
        }

        $unverified = Resolve-DiscoveryEvidence -State $state -Evidence @{
            Classification      = 'OBSERVED_PASS'
            Candidate           = -17
            CandidateAttemptId  = 'candidate-core2--17'
            ApplicationVerified = $false
            CompleteSuite       = $true
            StageAttemptIds     = @{ kagari = 'stage-kagari-17'; sse = 'stage-sse-17' }
        }

        $unverified.Accepted | Should Be $false
        $unverified.Reason | Should Be 'application_not_verified'
        $unverified.State['currentCandidate'] | Should Be -17

        $wrongCandidateAttempt = Resolve-DiscoveryEvidence -State $state -Evidence @{
            Classification      = 'OBSERVED_PASS'
            Candidate           = -17
            CandidateAttemptId  = 'stage-kagari-17'
            ApplicationVerified = $true
            CompleteSuite       = $true
            StageAttemptIds     = @{ kagari = 'stage-kagari-17'; sse = 'stage-sse-17' }
        }

        $wrongCandidateAttempt.Accepted | Should Be $false
        $wrongCandidateAttempt.Reason | Should Be 'candidate_attempt_mismatch'

        $wrongStageAttempt = Resolve-DiscoveryEvidence -State $state -Evidence @{
            Classification      = 'OBSERVED_PASS'
            Candidate           = -17
            CandidateAttemptId  = 'candidate-core2--17'
            ApplicationVerified = $true
            CompleteSuite       = $true
            StageAttemptIds     = @{ kagari = 'candidate-core2--17'; sse = 'stage-sse-17' }
        }

        $wrongStageAttempt.Accepted | Should Be $false
        $wrongStageAttempt.Reason | Should Be 'stage_attempt_mismatch'
    }


    It 'rejects candidate-attempt and stage-attempt identifier collisions at state creation' {
        {
            New-DiscoveryCoreState -CoreNumber 2 -CurrentCandidate -17 -PlatformMinimum -30 -CandidateAttemptId 'attempt-17' -StageAttemptIds @{
                kagari = 'attempt-17'
                sse    = 'stage-sse-17'
            }
        } | Should Throw 'Candidate attempt ID must not be reused by a stage attempt ID.'

        {
            New-DiscoveryCoreState -CoreNumber 2 -CurrentCandidate -17 -PlatformMinimum -30 -CandidateAttemptId 'candidate-core2--17' -StageAttemptIds @{
                kagari = 'stage-shared-17'
                sse    = 'stage-shared-17'
            }
        } | Should Throw 'Stage attempt IDs must be unique.'
    }

}


Describe 'Discovery state persistence' {
    It 'persists interruption status so only unverified attempts can retry with fresh identities' {
        $pending = New-DiscoveryCoreState -CoreNumber 2 -CurrentCandidate -18 -PlatformMinimum -30 -CandidateAttemptId 'candidate-core2--18-a' -StageAttemptIds @{ kagari = 'stage-kagari-18-a' }
        $pendingRoundTrip = Restore-DiscoveryStateSnapshot -Snapshot (ConvertTo-DiscoveryStateSnapshot -States @{ 2 = $pending })
        $retryDecision = Resolve-DiscoveryInterruption -State $pendingRoundTrip.States[2]

        $retryDecision.Accepted | Should Be $true
        $retryDecision.Disposition | Should Be 'RETRY_WITH_FRESH_IDENTITIES'
        (Test-DiscoveryCoreCanBeScheduled -State $retryDecision.State) | Should Be $false

        $retry = New-DiscoveryRetryState -State $retryDecision.State -CandidateAttemptId 'candidate-core2--18-b' -StageAttemptIds @{ kagari = 'stage-kagari-18-b' }
        $retry['candidateAttemptId'] | Should Be 'candidate-core2--18-b'
        $retry['stageAttemptIds']['kagari'] | Should Be 'stage-kagari-18-b'
        (Test-DiscoveryCoreCanBeScheduled -State $retry) | Should Be $true

        { New-DiscoveryRetryState -State $retryDecision.State -CandidateAttemptId 'candidate-core2--18-a' -StageAttemptIds @{ kagari = 'stage-kagari-18-b' } } | Should Throw 'A retry must use a fresh candidate attempt ID.'
        { New-DiscoveryRetryState -State $retryDecision.State -CandidateAttemptId 'candidate-core2--18-b' -StageAttemptIds @{ kagari = 'stage-kagari-18-a' } } | Should Throw 'A retry must use fresh stage attempt IDs.'
        { New-DiscoveryRetryState -State $retryDecision.State -CandidateAttemptId 'stage-kagari-18-a' -StageAttemptIds @{ kagari = 'stage-kagari-18-b' } } | Should Throw 'A retry must use a fresh candidate attempt ID.'
        { New-DiscoveryRetryState -State $retryDecision.State -CandidateAttemptId 'candidate-core2--18-b' -StageAttemptIds @{ kagari = 'candidate-core2--18-a' } } | Should Throw 'A retry must use fresh stage attempt IDs.'

        $verified = New-DiscoveryCoreState -CoreNumber 3 -CurrentCandidate -18 -PlatformMinimum -30 -CandidateAttemptId 'candidate-core3--18-a' -StageAttemptIds @{ kagari = 'stage-kagari-18-a' }
        $verified['attemptStatus'] = 'APPLIED_VERIFIED'
        $verifiedRoundTrip = Restore-DiscoveryStateSnapshot -Snapshot (ConvertTo-DiscoveryStateSnapshot -States @{ 3 = $verified })
        $quarantineDecision = Resolve-DiscoveryInterruption -State $verifiedRoundTrip.States[3]

        $quarantineDecision.Accepted | Should Be $true
        $quarantineDecision.Disposition | Should Be 'QUARANTINE'
        $quarantineDecision.State['resolution'] | Should Be 'QUARANTINED_AMBIGUOUS'
        $quarantineDecision.State['attemptStatus'] | Should Be 'QUARANTINED_INTERRUPTION'
        (Test-DiscoveryCoreCanBeScheduled -State $quarantineDecision.State) | Should Be $false
    }

    It 'round-trips a discovery state without aliasing its attempt metadata' {
        $state = New-DiscoveryCoreState -CoreNumber 2 -CurrentCandidate -18 -PlatformMinimum -30 -CandidateAttemptId 'candidate-core2--18' -StageAttemptIds @{
            kagari = 'stage-kagari-18'
            sse    = 'stage-sse-18'
        }
        $state['lastObservedPass'] = -17

        $snapshot = ConvertTo-DiscoveryStateSnapshot -States @{ 2 = $state }
        $json = ConvertTo-Json $snapshot -Depth 8
        $restored = Restore-DiscoveryStateSnapshot -Snapshot (ConvertFrom-Json $json)

        $restored.Accepted | Should Be $true
        $restored.States[2]['currentCandidate'] | Should Be -18
        $restored.States[2]['lastObservedPass'] | Should Be -17
        $restored.States[2]['candidateAttemptId'] | Should Be 'candidate-core2--18'
        $restored.States[2]['stageAttemptIds']['kagari'] | Should Be 'stage-kagari-18'

        $restored.States[2]['stageAttemptIds']['kagari'] = 'changed-after-restore'
        $state['stageAttemptIds']['kagari'] | Should Be 'stage-kagari-18'
    }

    It 'rejects stale candidate-attempt state before returning any recovered core' {
        $state = New-DiscoveryCoreState -CoreNumber 2 -CurrentCandidate -18 -PlatformMinimum -30 -CandidateAttemptId 'candidate-core2--18' -StageAttemptIds @{ kagari = 'stage-kagari-18' }
        $snapshot = ConvertTo-DiscoveryStateSnapshot -States @{ 2 = $state }

        $restored = Restore-DiscoveryStateSnapshot -Snapshot $snapshot -ExpectedCandidateAttemptIds @{ 2 = 'candidate-core2--19' }

        $restored.Accepted | Should Be $false
        $restored.Reason | Should Be 'stale_candidate_attempt'
        $restored.States.Count | Should Be 0
    }

    It 'rejects multi-core stale identity without returning the other recovered core' {
        $core2 = New-DiscoveryCoreState -CoreNumber 2 -CurrentCandidate -18 -PlatformMinimum -30 -CandidateAttemptId 'candidate-core2--18' -StageAttemptIds @{ kagari = 'stage-kagari-18' }
        $core3 = New-DiscoveryCoreState -CoreNumber 3 -CurrentCandidate -19 -PlatformMinimum -30 -CandidateAttemptId 'candidate-core3--19' -StageAttemptIds @{ kagari = 'stage-kagari-19' }
        $snapshot = ConvertTo-DiscoveryStateSnapshot -States @{ 2 = $core2; 3 = $core3 }

        $restored = Restore-DiscoveryStateSnapshot -Snapshot $snapshot -ExpectedCandidateAttemptIds @{
            2 = 'candidate-core2--18'
            3 = 'candidate-core3--20'
        }

        $restored.Accepted | Should Be $false
        $restored.Reason | Should Be 'stale_candidate_attempt'
        $restored.States.Count | Should Be 0
    }

    It 'rejects a snapshot that omits an expected core instead of partially recovering the others' {
        $core3 = New-DiscoveryCoreState -CoreNumber 3 -CurrentCandidate -19 -PlatformMinimum -30 -CandidateAttemptId 'candidate-core3--19' -StageAttemptIds @{ kagari = 'stage-kagari-19' }
        $snapshot = ConvertTo-DiscoveryStateSnapshot -States @{ 3 = $core3 }

        $restored = Restore-DiscoveryStateSnapshot -Snapshot $snapshot -ExpectedCandidateAttemptIds @{
            2 = 'candidate-core2--18'
            3 = 'candidate-core3--19'
        }

        $restored.Accepted | Should Be $false
        $restored.Reason | Should Be 'expected_core_set_mismatch'
        $restored.States.Count | Should Be 0
    }

    It 'rejects torn state rather than recovering a partial core' {
        $tornSnapshot = [PSCustomObject]@{
            schemaVersion = 2
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

        $restored = Restore-DiscoveryStateSnapshot -Snapshot $tornSnapshot

        $restored.Accepted | Should Be $false
        $restored.Reason | Should Be 'invalid_state'
        $restored.States.Count | Should Be 0
    }

    It 'rejects a candidate below the persisted platform minimum' {
        $belowMinimumSnapshot = [PSCustomObject]@{
            schemaVersion = 2
            states = [PSCustomObject]@{
                '2' = [PSCustomObject]@{
                    coreNumber = 2
                    currentCandidate = -31
                    platformMinimum = -30
                    candidateAttemptId = 'candidate-core2--31'
                    stageAttemptIds = [PSCustomObject]@{ kagari = 'stage-kagari-31' }
                    lastObservedPass = -30
                    firstObservedFail = $null
                    discoveryCandidate = $null
                    resolution = $null
                }
            }
        }

        $restored = Restore-DiscoveryStateSnapshot -Snapshot $belowMinimumSnapshot

        $restored.Accepted | Should Be $false
        $restored.Reason | Should Be 'invalid_state'
        $restored.States.Count | Should Be 0
    }

    It 'rejects a terminal discovery candidate without the supporting pass and failure evidence' {
        $invalidTerminalSnapshot = [PSCustomObject]@{
            schemaVersion = 2
            states = [PSCustomObject]@{
                '2' = [PSCustomObject]@{
                    coreNumber = 2
                    currentCandidate = -18
                    platformMinimum = -30
                    candidateAttemptId = 'candidate-core2--18'
                    stageAttemptIds = [PSCustomObject]@{ kagari = 'stage-kagari-18' }
                    lastObservedPass = $null
                    firstObservedFail = $null
                    discoveryCandidate = -17
                    resolution = 'DISCOVERY_CANDIDATE'
                }
            }
        }

        $restored = Restore-DiscoveryStateSnapshot -Snapshot $invalidTerminalSnapshot

        $restored.Accepted | Should Be $false
        $restored.Reason | Should Be 'invalid_state'
        $restored.States.Count | Should Be 0
    }

    It 'restores terminal state without making it schedulable' {
        $state = New-DiscoveryCoreState -CoreNumber 2 -CurrentCandidate -18 -PlatformMinimum -30 -CandidateAttemptId 'candidate-core2--18' -StageAttemptIds @{ kagari = 'stage-kagari-18' }
        $state['lastObservedPass'] = -17
        $state['firstObservedFail'] = -18
        $state['discoveryCandidate'] = -17
        $state['resolution'] = 'DISCOVERY_CANDIDATE'

        $restored = Restore-DiscoveryStateSnapshot -Snapshot (ConvertTo-DiscoveryStateSnapshot -States @{ 2 = $state })

        $restored.Accepted | Should Be $true
        $restored.States[2]['resolution'] | Should Be 'DISCOVERY_CANDIDATE'
        (Test-DiscoveryCoreCanBeScheduled -State $restored.States[2]) | Should Be $false
    }
}
