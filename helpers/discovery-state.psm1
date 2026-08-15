Set-StrictMode -Version Latest

function Copy-DiscoveryCoreState {
    param(
        [Parameter(Mandatory=$true)] [hashtable] $State
    )

    $copy = @{}

    foreach ($key in $State.Keys) {
        if ($key -eq 'stageAttemptIds') {
            $copy[$key] = @{}

            foreach ($stageName in $State[$key].Keys) {
                $copy[$key][$stageName] = $State[$key][$stageName]
            }
        }
        else {
            $copy[$key] = $State[$key]
        }
    }

    return $copy
}

function New-DiscoveryCoreState {
    param(
        [Parameter(Mandatory=$true)] [Int] $CoreNumber,
        [Parameter(Mandatory=$true)] [Int] $CurrentCandidate,
        [Parameter(Mandatory=$true)] [Int] $PlatformMinimum,
        [Parameter(Mandatory=$true)] [String] $CandidateAttemptId,
        [Parameter(Mandatory=$true)] [hashtable] $StageAttemptIds
    )

    $stageAttemptValues = @($StageAttemptIds.Values)

    if ($stageAttemptValues -contains $CandidateAttemptId) {
        throw 'Candidate attempt ID must not be reused by a stage attempt ID.'
    }

    if (@($stageAttemptValues | Select-Object -Unique).Count -ne $stageAttemptValues.Count) {
        throw 'Stage attempt IDs must be unique.'
    }

    return @{
        'coreNumber'         = $CoreNumber
        'currentCandidate'   = $CurrentCandidate
        'platformMinimum'    = $PlatformMinimum
        'candidateAttemptId' = $CandidateAttemptId
        'stageAttemptIds'    = (Copy-DiscoveryCoreState -State @{ 'stageAttemptIds' = $StageAttemptIds })['stageAttemptIds']
        'attemptStatus'      = 'PENDING'
        'lastObservedPass'   = $null
        'firstObservedFail'  = $null
        'discoveryCandidate' = $null
        'resolution'         = $null
    }
}

function Test-DiscoveryEvidenceIdentity {
    param(
        [Parameter(Mandatory=$true)] [hashtable] $State,
        [Parameter(Mandatory=$true)] [hashtable] $Evidence
    )

    if ($Evidence['Candidate'] -ne $State['currentCandidate']) {
        return 'candidate_value_mismatch'
    }

    if ($Evidence['CandidateAttemptId'] -ne $State['candidateAttemptId']) {
        return 'candidate_attempt_mismatch'
    }

    if (!($Evidence['StageAttemptIds'] -is [hashtable]) -or $Evidence['StageAttemptIds'].Count -ne $State['stageAttemptIds'].Count) {
        return 'stage_attempt_mismatch'
    }

    foreach ($stageName in $State['stageAttemptIds'].Keys) {
        if (!$Evidence['StageAttemptIds'].ContainsKey($stageName) -or $Evidence['StageAttemptIds'][$stageName] -ne $State['stageAttemptIds'][$stageName]) {
            return 'stage_attempt_mismatch'
        }
    }

    return ''
}

function Test-DiscoveryCoreCanBeScheduled {
    param(
        [Parameter(Mandatory=$true)] [hashtable] $State
    )

    return !(@('DISCOVERY_CANDIDATE', 'NO_VALID_BASELINE', 'PLATFORM_LIMIT_REACHED', 'QUARANTINED_AMBIGUOUS') -contains $State['resolution']) -and $State['attemptStatus'] -ne 'RETRY_REQUIRED'
}

function Assert-DiscoveryStateConsistency {
    param(
        [Parameter(Mandatory=$true)] [hashtable] $State
    )

    if ($State['currentCandidate'] -lt $State['platformMinimum']) {
        throw 'Discovery state candidate is below the platform minimum.'
    }

    if (!(@('PENDING', 'APPLIED_VERIFIED', 'RETRY_REQUIRED', 'QUARANTINED_INTERRUPTION') -contains $State['attemptStatus'])) {
        throw 'Discovery state contains an unsupported attempt status.'
    }

    if ($State['attemptStatus'] -eq 'RETRY_REQUIRED' -and $null -ne $State['resolution']) {
        throw 'A retry-required discovery state must not have a terminal resolution.'
    }

    if ($State['attemptStatus'] -eq 'QUARANTINED_INTERRUPTION' -and $State['resolution'] -ne 'QUARANTINED_AMBIGUOUS') {
        throw 'An interruption-quarantined discovery state must be ambiguously resolved.'
    }

    if ($State['resolution'] -eq 'DISCOVERY_CANDIDATE') {
        if ($null -eq $State['lastObservedPass'] -or $null -eq $State['firstObservedFail'] -or $null -eq $State['discoveryCandidate']) {
            throw 'Discovery candidate resolution requires observed pass and attributable failure evidence.'
        }

        if ($State['firstObservedFail'] -ne $State['currentCandidate'] -or $State['discoveryCandidate'] -ne $State['lastObservedPass']) {
            throw 'Discovery candidate resolution is inconsistent with its evidence.'
        }
    }
}

function Resolve-DiscoveryInterruption {
    param(
        [Parameter(Mandatory=$true)] [hashtable] $State
    )

    Assert-DiscoveryStateConsistency -State $State
    $nextState = Copy-DiscoveryCoreState -State $State

    if ($State['attemptStatus'] -eq 'APPLIED_VERIFIED') {
        $nextState['attemptStatus'] = 'QUARANTINED_INTERRUPTION'
        $nextState['resolution'] = 'QUARANTINED_AMBIGUOUS'
        return [PSCustomObject]@{ Accepted = $true; Disposition = 'QUARANTINE'; State = $nextState }
    }

    if ($State['attemptStatus'] -eq 'PENDING') {
        $nextState['attemptStatus'] = 'RETRY_REQUIRED'
        return [PSCustomObject]@{ Accepted = $true; Disposition = 'RETRY_WITH_FRESH_IDENTITIES'; State = $nextState }
    }

    return [PSCustomObject]@{ Accepted = $false; Disposition = 'NO_RECOVERY_ACTION'; State = $nextState }
}

function New-DiscoveryRetryState {
    param(
        [Parameter(Mandatory=$true)] [hashtable] $State,
        [Parameter(Mandatory=$true)] [String] $CandidateAttemptId,
        [Parameter(Mandatory=$true)] [hashtable] $StageAttemptIds
    )

    Assert-DiscoveryStateConsistency -State $State

    if ($State['attemptStatus'] -ne 'RETRY_REQUIRED') {
        throw 'Only a retry-required discovery state can create a retry attempt.'
    }

    $priorAttemptIds = @($State['candidateAttemptId']) + @($State['stageAttemptIds'].Values)

    if ($priorAttemptIds -contains $CandidateAttemptId) {
        throw 'A retry must use a fresh candidate attempt ID.'
    }

    foreach ($stageAttemptId in $StageAttemptIds.Values) {
        if ($priorAttemptIds -contains $stageAttemptId) {
            throw 'A retry must use fresh stage attempt IDs.'
        }
    }

    $retryState = New-DiscoveryCoreState -CoreNumber $State['coreNumber'] -CurrentCandidate $State['currentCandidate'] -PlatformMinimum $State['platformMinimum'] -CandidateAttemptId $CandidateAttemptId -StageAttemptIds $StageAttemptIds
    $retryState['lastObservedPass'] = $State['lastObservedPass']
    return $retryState
}

function Resolve-DiscoveryEvidence {
    param(
        [Parameter(Mandatory=$true)] [hashtable] $State,
        [Parameter(Mandatory=$true)] [hashtable] $Evidence
    )

    $nextState = Copy-DiscoveryCoreState -State $State

    if (!$Evidence['ApplicationVerified']) {
        return [PSCustomObject]@{ Accepted = $false; Reason = 'application_not_verified'; State = $nextState }
    }

    $identityError = Test-DiscoveryEvidenceIdentity -State $State -Evidence $Evidence

    if ($identityError.Length -gt 0) {
        return [PSCustomObject]@{ Accepted = $false; Reason = $identityError; State = $nextState }
    }

    if ($Evidence['Classification'] -eq 'ATTRIBUTED_FAIL') {
        $nextState['firstObservedFail'] = $State['currentCandidate']

        if ($null -eq $State['lastObservedPass']) {
            $nextState['resolution'] = 'NO_VALID_BASELINE'
        }
        else {
            $nextState['discoveryCandidate'] = $State['lastObservedPass']
            $nextState['resolution'] = 'DISCOVERY_CANDIDATE'
        }

        return [PSCustomObject]@{ Accepted = $true; Reason = ''; State = $nextState }
    }

    if ($Evidence['Classification'] -eq 'AMBIGUOUS_FAIL') {
        $nextState['resolution'] = 'QUARANTINED_AMBIGUOUS'
        return [PSCustomObject]@{ Accepted = $true; Reason = 'ambiguous_failure'; State = $nextState }
    }

    if ($Evidence['Classification'] -eq 'INFRASTRUCTURE_INVALID') {
        return [PSCustomObject]@{ Accepted = $true; Reason = 'infrastructure_invalid'; State = $nextState }
    }

    if ($Evidence['Classification'] -ne 'OBSERVED_PASS') {
        return [PSCustomObject]@{ Accepted = $false; Reason = 'unsupported_classification'; State = $nextState }
    }

    if (!$Evidence['CompleteSuite']) {
        return [PSCustomObject]@{ Accepted = $false; Reason = 'suite_incomplete'; State = $nextState }
    }

    $nextState['lastObservedPass'] = $State['currentCandidate']

    if ($State['currentCandidate'] -le $State['platformMinimum']) {
        $nextState['resolution'] = 'PLATFORM_LIMIT_REACHED'
    }
    else {
        $nextState['currentCandidate'] = $State['currentCandidate'] - 1
    }

    return [PSCustomObject]@{ Accepted = $true; Reason = ''; State = $nextState }
}


function Get-DiscoverySnapshotValue {
    param(
        [Parameter(Mandatory=$true)] $InputObject,
        [Parameter(Mandatory=$true)] [String] $Name,
        [Parameter(Mandatory=$true)] [Switch] $Required
    )

    if ($InputObject -is [hashtable]) {
        if ($InputObject.ContainsKey($Name)) {
            return $InputObject[$Name]
        }
    }
    elseif ($InputObject -and ($InputObject | Get-Member -Name $Name)) {
        return $InputObject.$Name
    }

    if ($Required.IsPresent) {
        throw ('Discovery snapshot is missing required entry "' + $Name + '".')
    }

    return $null
}

function ConvertTo-DiscoveryStageAttemptIds {
    param(
        [Parameter(Mandatory=$true)] $StageAttemptIds
    )

    $normalizedStageAttemptIds = @{}

    if ($StageAttemptIds -is [hashtable]) {
        foreach ($entry in $StageAttemptIds.GetEnumerator()) {
            $normalizedStageAttemptIds[[String] $entry.Name] = [String] $entry.Value
        }
    }
    elseif ($StageAttemptIds) {
        foreach ($property in $StageAttemptIds.PSObject.Properties) {
            $normalizedStageAttemptIds[[String] $property.Name] = [String] $property.Value
        }
    }
    else {
        throw 'Discovery snapshot stage attempt IDs must be an object.'
    }

    return $normalizedStageAttemptIds
}

function ConvertTo-DiscoveryStateSnapshot {
    param(
        [Parameter(Mandatory=$true)] [hashtable] $States
    )

    $statesForSnapshot = @{}

    foreach ($entry in @($States.GetEnumerator() | Sort-Object -Property { [Int] $_.Name })) {
        $coreNumber = [Int] $entry.Name
        $state = $entry.Value

        if (!($state -is [hashtable])) {
            throw 'Discovery state must be a hashtable.'
        }

        if ([Int] (Get-DiscoverySnapshotValue -InputObject $state -Name 'coreNumber' -Required) -ne $coreNumber) {
            throw 'Discovery snapshot core key must match the embedded core number.'
        }

        $stageAttemptIds = ConvertTo-DiscoveryStageAttemptIds -StageAttemptIds (Get-DiscoverySnapshotValue -InputObject $state -Name 'stageAttemptIds' -Required)
        $normalizedState = New-DiscoveryCoreState -CoreNumber $coreNumber -CurrentCandidate ([Int] (Get-DiscoverySnapshotValue -InputObject $state -Name 'currentCandidate' -Required)) -PlatformMinimum ([Int] (Get-DiscoverySnapshotValue -InputObject $state -Name 'platformMinimum' -Required)) -CandidateAttemptId ([String] (Get-DiscoverySnapshotValue -InputObject $state -Name 'candidateAttemptId' -Required)) -StageAttemptIds $stageAttemptIds
        $normalizedState['attemptStatus'] = [String] (Get-DiscoverySnapshotValue -InputObject $state -Name 'attemptStatus' -Required)

        foreach ($name in @('lastObservedPass', 'firstObservedFail', 'discoveryCandidate')) {
            $value = Get-DiscoverySnapshotValue -InputObject $state -Name $name -Required
            $normalizedState[$name] = $(if ($null -eq $value) { $null } else { [Int] $value })
        }

        $resolution = Get-DiscoverySnapshotValue -InputObject $state -Name 'resolution' -Required

        if ($null -eq $resolution -or [String]::IsNullOrWhiteSpace([String] $resolution)) {
            $normalizedState['resolution'] = $null
        }
        elseif (@('DISCOVERY_CANDIDATE', 'NO_VALID_BASELINE', 'PLATFORM_LIMIT_REACHED', 'QUARANTINED_AMBIGUOUS') -contains [String] $resolution) {
            $normalizedState['resolution'] = [String] $resolution
        }
        else {
            throw 'Discovery snapshot contains an unsupported resolution.'
        }

        Assert-DiscoveryStateConsistency -State $normalizedState
        $statesForSnapshot[$coreNumber.ToString()] = $normalizedState
    }

    return @{
        'schemaVersion' = 2
        'states'        = $statesForSnapshot
    }
}

function Restore-DiscoveryStateSnapshot {
    param(
        [Parameter(Mandatory=$true)] $Snapshot,
        [Parameter(Mandatory=$false)] [hashtable] $ExpectedCandidateAttemptIds = @{}
    )

    try {
        if ([Int] (Get-DiscoverySnapshotValue -InputObject $Snapshot -Name 'schemaVersion' -Required) -ne 2) {
            return [PSCustomObject]@{ Accepted = $false; Reason = 'unsupported_schema'; States = @{} }
        }

        $statesObject = Get-DiscoverySnapshotValue -InputObject $Snapshot -Name 'states' -Required
        $states = @{}

        if ($statesObject -is [hashtable]) {
            $entries = @($statesObject.GetEnumerator())
        }
        elseif ($statesObject) {
            $entries = @($statesObject.PSObject.Properties | ForEach-Object {
                [PSCustomObject]@{ Name = $_.Name; Value = $_.Value }
            })
        }
        else {
            throw 'Discovery snapshot states must be an object.'
        }

        foreach ($entry in $entries) {
            $coreNumber = [Int] $entry.Name
            $stateObject = $entry.Value
            $stageAttemptIds = ConvertTo-DiscoveryStageAttemptIds -StageAttemptIds (Get-DiscoverySnapshotValue -InputObject $stateObject -Name 'stageAttemptIds' -Required)
            $state = New-DiscoveryCoreState -CoreNumber ([Int] (Get-DiscoverySnapshotValue -InputObject $stateObject -Name 'coreNumber' -Required)) -CurrentCandidate ([Int] (Get-DiscoverySnapshotValue -InputObject $stateObject -Name 'currentCandidate' -Required)) -PlatformMinimum ([Int] (Get-DiscoverySnapshotValue -InputObject $stateObject -Name 'platformMinimum' -Required)) -CandidateAttemptId ([String] (Get-DiscoverySnapshotValue -InputObject $stateObject -Name 'candidateAttemptId' -Required)) -StageAttemptIds $stageAttemptIds
            $state['attemptStatus'] = [String] (Get-DiscoverySnapshotValue -InputObject $stateObject -Name 'attemptStatus' -Required)

            if ($state['coreNumber'] -ne $coreNumber) {
                throw 'Discovery snapshot core key must match the embedded core number.'
            }

            if ($ExpectedCandidateAttemptIds.ContainsKey($coreNumber) -and $state['candidateAttemptId'] -ne [String] $ExpectedCandidateAttemptIds[$coreNumber]) {
                return [PSCustomObject]@{ Accepted = $false; Reason = 'stale_candidate_attempt'; States = @{} }
            }

            foreach ($name in @('lastObservedPass', 'firstObservedFail', 'discoveryCandidate')) {
                $value = Get-DiscoverySnapshotValue -InputObject $stateObject -Name $name -Required
                $state[$name] = $(if ($null -eq $value) { $null } else { [Int] $value })
            }

            $resolution = Get-DiscoverySnapshotValue -InputObject $stateObject -Name 'resolution' -Required

            if ($null -eq $resolution -or [String]::IsNullOrWhiteSpace([String] $resolution)) {
                $state['resolution'] = $null
            }
            elseif (@('DISCOVERY_CANDIDATE', 'NO_VALID_BASELINE', 'PLATFORM_LIMIT_REACHED', 'QUARANTINED_AMBIGUOUS') -contains [String] $resolution) {
                $state['resolution'] = [String] $resolution
            }
            else {
                throw 'Discovery snapshot contains an unsupported resolution.'
            }

            Assert-DiscoveryStateConsistency -State $state
            $states[$coreNumber] = $state
        }

        # An expected identity set is recovery authority, not a partial filter.  A missing or unexpected core
        # indicates a stale or truncated snapshot, so never return the subset that happened to deserialize.
        if ($ExpectedCandidateAttemptIds.Count -gt 0) {
            if ($states.Count -ne $ExpectedCandidateAttemptIds.Count) {
                return [PSCustomObject]@{ Accepted = $false; Reason = 'expected_core_set_mismatch'; States = @{} }
            }

            foreach ($expectedCoreNumber in $ExpectedCandidateAttemptIds.Keys) {
                if (!$states.ContainsKey([Int] $expectedCoreNumber)) {
                    return [PSCustomObject]@{ Accepted = $false; Reason = 'expected_core_set_mismatch'; States = @{} }
                }
            }
        }

        return [PSCustomObject]@{ Accepted = $true; Reason = ''; States = $states }
    }
    catch {
        return [PSCustomObject]@{ Accepted = $false; Reason = 'invalid_state'; States = @{} }
    }
}

Export-ModuleMember -Function New-DiscoveryCoreState, New-DiscoveryRetryState, Resolve-DiscoveryEvidence, Resolve-DiscoveryInterruption, Test-DiscoveryCoreCanBeScheduled, ConvertTo-DiscoveryStateSnapshot, Restore-DiscoveryStateSnapshot
