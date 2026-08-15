Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'discovery-state.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'discovery-stage.psm1') -Force

function Copy-DiscoverySuiteState {
    param(
        [Parameter(Mandatory=$true)] [hashtable] $State
    )

    $copy = @{}
    foreach ($key in $State.Keys) {
        if ($key -eq 'stageAttemptIds' -and $State[$key] -is [hashtable]) {
            $copy[$key] = @{}
            foreach ($stageKey in $State[$key].Keys) {
                $copy[$key][$stageKey] = $State[$key][$stageKey]
            }
        }
        else {
            $copy[$key] = $State[$key]
        }
    }

    return $copy
}

function Test-DiscoveryRequiredWorkloadSet {
    param(
        [Parameter(Mandatory=$true)] [hashtable] $State,
        [Parameter(Mandatory=$true)] [String[]] $RequiredWorkloadIds
    )

    if ($RequiredWorkloadIds.Count -eq 0 -or @($RequiredWorkloadIds | Where-Object { [String]::IsNullOrWhiteSpace($_) }).Count -gt 0 -or @($RequiredWorkloadIds | Select-Object -Unique).Count -ne $RequiredWorkloadIds.Count) {
        return $false
    }

    if (!($State['stageAttemptIds'] -is [hashtable]) -or $State['stageAttemptIds'].Count -ne $RequiredWorkloadIds.Count) {
        return $false
    }

    foreach ($workloadId in $RequiredWorkloadIds) {
        if (!$State['stageAttemptIds'].ContainsKey($workloadId) -or [String]::IsNullOrWhiteSpace([String] $State['stageAttemptIds'][$workloadId])) {
            return $false
        }
    }

    return $true
}

function Resolve-DiscoverySuiteStage {
    param(
        [Parameter(Mandatory=$true)] [hashtable] $State,
        [Parameter(Mandatory=$true)] [hashtable] $Context,
        [Parameter(Mandatory=$true)] [hashtable] $Result,
        [Parameter(Mandatory=$true)] [String[]] $RequiredWorkloadIds,
        [Parameter(Mandatory=$true)][AllowEmptyCollection()] [String[]] $CompletedWorkloadIds,
        [Parameter(Mandatory=$true)] [Int] $CurrentStageIndex
    )

    $unchangedState = Copy-DiscoverySuiteState -State $State
    $completedWorkloadIdsCopy = @($CompletedWorkloadIds)

    if ($CurrentStageIndex -ne $completedWorkloadIdsCopy.Count -or $completedWorkloadIdsCopy.Count -gt $RequiredWorkloadIds.Count) {
        return [PSCustomObject]@{ Accepted = $false; Reason = 'suite_progress_mismatch'; Disposition = 'REJECTED'; NextStageIndex = $CurrentStageIndex; NextWorkloadId = $null; CompletedWorkloadIds = $completedWorkloadIdsCopy; State = $unchangedState }
    }

    for ($index = 0; $index -lt $completedWorkloadIdsCopy.Count; $index++) {
        if ($completedWorkloadIdsCopy[$index] -ne $RequiredWorkloadIds[$index]) {
            return [PSCustomObject]@{ Accepted = $false; Reason = 'suite_progress_mismatch'; Disposition = 'REJECTED'; NextStageIndex = $CurrentStageIndex; NextWorkloadId = $null; CompletedWorkloadIds = $completedWorkloadIdsCopy; State = $unchangedState }
        }
    }

    if ($State['attemptStatus'] -ne 'APPLIED_VERIFIED') {
        return [PSCustomObject]@{ Accepted = $false; Reason = 'application_not_verified'; Disposition = 'REJECTED'; NextStageIndex = $CurrentStageIndex; NextWorkloadId = $null; CompletedWorkloadIds = $completedWorkloadIdsCopy; State = $unchangedState }
    }

    if (!(Test-DiscoveryRequiredWorkloadSet -State $State -RequiredWorkloadIds $RequiredWorkloadIds) -or $CurrentStageIndex -lt 0 -or $CurrentStageIndex -ge $RequiredWorkloadIds.Count) {
        return [PSCustomObject]@{ Accepted = $false; Reason = 'suite_stage_map_mismatch'; Disposition = 'REJECTED'; NextStageIndex = $CurrentStageIndex; NextWorkloadId = $null; CompletedWorkloadIds = $completedWorkloadIdsCopy; State = $unchangedState }
    }

    $currentWorkloadId = $RequiredWorkloadIds[$CurrentStageIndex]
    if ($Context['coreNumber'] -ne $State['coreNumber'] -or $Context['candidate'] -ne $State['currentCandidate'] -or $Context['candidateAttemptId'] -ne $State['candidateAttemptId'] -or $Context['workloadId'] -ne $currentWorkloadId -or $Context['stageAttemptId'] -ne $State['stageAttemptIds'][$currentWorkloadId]) {
        return [PSCustomObject]@{ Accepted = $false; Reason = 'stage_context_mismatch'; Disposition = 'REJECTED'; NextStageIndex = $CurrentStageIndex; NextWorkloadId = $null; CompletedWorkloadIds = $completedWorkloadIdsCopy; State = $unchangedState }
    }

    $stageDecision = Test-DiscoveryStageResult -Context $Context -Result $Result
    if (!$stageDecision.Accepted) {
        return [PSCustomObject]@{ Accepted = $false; Reason = $stageDecision.Reason; Disposition = 'REJECTED'; NextStageIndex = $CurrentStageIndex; NextWorkloadId = $null; CompletedWorkloadIds = $completedWorkloadIdsCopy; State = $unchangedState }
    }

    if (!($Result.ContainsKey('childExited')) -or !($Result['childExited'] -is [Bool]) -or $Result['childExited'] -ne $true -or !($Result.ContainsKey('expectedStressProcessCleanupVerified')) -or !($Result['expectedStressProcessCleanupVerified'] -is [Bool]) -or $Result['expectedStressProcessCleanupVerified'] -ne $true) {
        return [PSCustomObject]@{ Accepted = $false; Reason = 'child_lifecycle_unverified'; Disposition = 'REJECTED'; NextStageIndex = $CurrentStageIndex; NextWorkloadId = $null; CompletedWorkloadIds = $completedWorkloadIdsCopy; State = $unchangedState }
    }

    if ($Result['outcome'] -eq 'PASS' -and $CurrentStageIndex -lt ($RequiredWorkloadIds.Count - 1)) {
        $nextStageIndex = $CurrentStageIndex + 1
        return [PSCustomObject]@{ Accepted = $true; Reason = ''; Disposition = 'ADVANCE_STAGE'; NextStageIndex = $nextStageIndex; NextWorkloadId = $RequiredWorkloadIds[$nextStageIndex]; CompletedWorkloadIds = @($completedWorkloadIdsCopy + $currentWorkloadId); State = $unchangedState }
    }

    if ($Result['outcome'] -eq 'PASS') {
        $evidence = @{
            ApplicationVerified = $true
            Candidate           = $State['currentCandidate']
            CandidateAttemptId  = $State['candidateAttemptId']
            StageAttemptIds     = $State['stageAttemptIds']
            Classification      = 'OBSERVED_PASS'
            CompleteSuite       = $true
        }
        $evidenceDecision = Resolve-DiscoveryEvidence -State $State -Evidence $evidence

        if (!$evidenceDecision.Accepted) {
            return [PSCustomObject]@{ Accepted = $false; Reason = $evidenceDecision.Reason; Disposition = 'REJECTED'; NextStageIndex = $CurrentStageIndex; NextWorkloadId = $null; CompletedWorkloadIds = @($completedWorkloadIdsCopy + $currentWorkloadId); State = $evidenceDecision.State }
        }

        return [PSCustomObject]@{ Accepted = $true; Reason = $evidenceDecision.Reason; Disposition = 'CANDIDATE_EVIDENCE_RECORDED'; NextStageIndex = $CurrentStageIndex; NextWorkloadId = $null; CompletedWorkloadIds = @($completedWorkloadIdsCopy + $currentWorkloadId); State = $evidenceDecision.State }
    }

    if ($Result['outcome'] -eq 'ATTRIBUTED_FAIL') {
        $evidence = @{
            ApplicationVerified = $true
            Candidate           = $State['currentCandidate']
            CandidateAttemptId  = $State['candidateAttemptId']
            StageAttemptIds     = $State['stageAttemptIds']
            Classification      = 'ATTRIBUTED_FAIL'
            CompleteSuite       = $false
        }
        $evidenceDecision = Resolve-DiscoveryEvidence -State $State -Evidence $evidence
        return [PSCustomObject]@{ Accepted = $evidenceDecision.Accepted; Reason = $evidenceDecision.Reason; Disposition = $(if ($evidenceDecision.Accepted) { 'CANDIDATE_EVIDENCE_RECORDED' } else { 'REJECTED' }); NextStageIndex = $CurrentStageIndex; NextWorkloadId = $null; CompletedWorkloadIds = $completedWorkloadIdsCopy; State = $evidenceDecision.State }
    }

    if ($Result['outcome'] -eq 'AMBIGUOUS_FAIL') {
        $evidence = @{
            ApplicationVerified = $true
            Candidate           = $State['currentCandidate']
            CandidateAttemptId  = $State['candidateAttemptId']
            StageAttemptIds     = $State['stageAttemptIds']
            Classification      = 'AMBIGUOUS_FAIL'
            CompleteSuite       = $false
        }
        $evidenceDecision = Resolve-DiscoveryEvidence -State $State -Evidence $evidence
        return [PSCustomObject]@{ Accepted = $evidenceDecision.Accepted; Reason = $evidenceDecision.Reason; Disposition = $(if ($evidenceDecision.Accepted) { 'CANDIDATE_EVIDENCE_RECORDED' } else { 'REJECTED' }); NextStageIndex = $CurrentStageIndex; NextWorkloadId = $null; CompletedWorkloadIds = $completedWorkloadIdsCopy; State = $evidenceDecision.State }
    }

    if ($Result['outcome'] -eq 'INFRASTRUCTURE_INVALID') {
        $evidence = @{
            ApplicationVerified = $true
            Candidate           = $State['currentCandidate']
            CandidateAttemptId  = $State['candidateAttemptId']
            StageAttemptIds     = $State['stageAttemptIds']
            Classification      = 'INFRASTRUCTURE_INVALID'
            CompleteSuite       = $false
        }
        $evidenceDecision = Resolve-DiscoveryEvidence -State $State -Evidence $evidence
        return [PSCustomObject]@{ Accepted = $evidenceDecision.Accepted; Reason = $evidenceDecision.Reason; Disposition = $(if ($evidenceDecision.Accepted) { 'RETRY_REQUIRES_FRESH_STAGE_IDENTITY' } else { 'REJECTED' }); RequiresFreshStageIdentity = $evidenceDecision.Accepted; NextStageIndex = $CurrentStageIndex; NextWorkloadId = $null; CompletedWorkloadIds = $completedWorkloadIdsCopy; State = $evidenceDecision.State }
    }

    return [PSCustomObject]@{ Accepted = $false; Reason = 'final_stage_not_implemented'; Disposition = 'REJECTED'; NextStageIndex = $CurrentStageIndex; NextWorkloadId = $null; CompletedWorkloadIds = $completedWorkloadIdsCopy; State = $unchangedState }
}

Export-ModuleMember -Function Resolve-DiscoverySuiteStage
