function Get-DiscoveryStageConfigFingerprint {
    param(
        [Parameter(Mandatory=$true)] [String] $ConfigPath
    )

    $resolvedPath = [System.IO.Path]::GetFullPath($ConfigPath)
    if (!(Test-Path -LiteralPath $resolvedPath -PathType Leaf)) {
        throw 'Discovery stage config path does not exist or is not a file.'
    }

    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha256.ComputeHash([System.IO.File]::ReadAllBytes($resolvedPath))
        return ([BitConverter]::ToString($hash)).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha256.Dispose()
    }
}

function New-DiscoveryStageContext {
    param(
        [Parameter(Mandatory=$true)] [Int] $CoreNumber,
        [Parameter(Mandatory=$true)] [Int] $Candidate,
        [Parameter(Mandatory=$true)] [String] $CandidateAttemptId,
        [Parameter(Mandatory=$true)] [String] $StageAttemptId,
        [Parameter(Mandatory=$true)] [String] $WorkloadId,
        [Parameter(Mandatory=$true)] [String] $ConfigPath,
        [Parameter(Mandatory=$true)] [String] $LogPath,
        [Parameter(Mandatory=$true)] [Int] $ChildProcessId,
        [Parameter(Mandatory=$true)] [DateTime] $StartedAt
    )

    foreach ($field in @{
        CandidateAttemptId = $CandidateAttemptId
        StageAttemptId     = $StageAttemptId
        WorkloadId         = $WorkloadId
    }.GetEnumerator()) {
        if ([String]::IsNullOrWhiteSpace($field.Value)) {
            throw ('Discovery stage ' + $field.Key + ' is required.')
        }
    }

    if ($CandidateAttemptId -eq $StageAttemptId) {
        throw 'Discovery stage and candidate attempt IDs must be distinct.'
    }

    if ($ChildProcessId -lt 1) {
        throw 'Discovery stage child process ID must be positive.'
    }

    $resolvedConfigPath = [System.IO.Path]::GetFullPath($ConfigPath)
    $resolvedLogPath = [System.IO.Path]::GetFullPath($LogPath)

    return @{
        coreNumber         = $CoreNumber
        candidate          = $Candidate
        candidateAttemptId = $CandidateAttemptId
        stageAttemptId     = $StageAttemptId
        workloadId         = $WorkloadId
        configPath         = $resolvedConfigPath
        configFingerprint  = Get-DiscoveryStageConfigFingerprint -ConfigPath $resolvedConfigPath
        logPath            = $resolvedLogPath
        childProcessId     = $ChildProcessId
        startedAt          = $StartedAt.ToUniversalTime()
    }
}

function Test-DiscoveryStageResult {
    param(
        [Parameter(Mandatory=$true)] [hashtable] $Context,
        [Parameter(Mandatory=$true)] [hashtable] $Result
    )

    if ([String]::IsNullOrWhiteSpace([String] $Result['candidateAttemptId'])) {
        return @{ Accepted = $false; Reason = 'missing_candidate_identity' }
    }

    if ([String]::IsNullOrWhiteSpace([String] $Result['stageAttemptId'])) {
        return @{ Accepted = $false; Reason = 'missing_stage_identity' }
    }

    if ($Result['candidateAttemptId'] -ne $Context['candidateAttemptId']) {
        return @{ Accepted = $false; Reason = 'stale_candidate_attempt' }
    }

    if ($Result['stageAttemptId'] -ne $Context['stageAttemptId']) {
        return @{ Accepted = $false; Reason = 'stale_stage_attempt' }
    }

    if (!($Result.ContainsKey('coreNumber')) -or $null -eq $Result['coreNumber'] -or ($Result['coreNumber'] -is [String] -and [String]::IsNullOrWhiteSpace($Result['coreNumber']))) {
        return @{ Accepted = $false; Reason = 'missing_core_identity' }
    }

    if (!($Result.ContainsKey('candidate')) -or $null -eq $Result['candidate'] -or ($Result['candidate'] -is [String] -and [String]::IsNullOrWhiteSpace($Result['candidate']))) {
        return @{ Accepted = $false; Reason = 'missing_candidate_value' }
    }

    if ($Result['workloadId'] -ne $Context['workloadId'] -or [Int] $Result['coreNumber'] -ne [Int] $Context['coreNumber'] -or [Int] $Result['candidate'] -ne [Int] $Context['candidate']) {
        return @{ Accepted = $false; Reason = 'stage_workload_mismatch' }
    }

    try {
        $currentConfigFingerprint = Get-DiscoveryStageConfigFingerprint -ConfigPath $Context['configPath']
    }
    catch {
        return @{ Accepted = $false; Reason = 'config_fingerprint_unavailable' }
    }

    if ([String]::IsNullOrWhiteSpace([String] $Result['configFingerprint']) -or $Result['configFingerprint'] -ne $Context['configFingerprint'] -or $currentConfigFingerprint -ne $Context['configFingerprint']) {
        return @{ Accepted = $false; Reason = 'config_fingerprint_mismatch' }
    }

    if ([String]::IsNullOrWhiteSpace([String] $Result['logPath']) -or [System.IO.Path]::GetFullPath([String] $Result['logPath']) -ne $Context['logPath'] -or !(Test-Path -LiteralPath $Context['logPath'] -PathType Leaf)) {
        return @{ Accepted = $false; Reason = 'stage_log_mismatch' }
    }

    if ([Int] $Result['childProcessId'] -ne [Int] $Context['childProcessId']) {
        return @{ Accepted = $false; Reason = 'stage_process_mismatch' }
    }

    if (([DateTime] $Result['startedAt']).ToUniversalTime() -ne ([DateTime] $Context['startedAt']).ToUniversalTime()) {
        return @{ Accepted = $false; Reason = 'stage_start_mismatch' }
    }

    if (!(@('PASS', 'ATTRIBUTED_FAIL', 'AMBIGUOUS_FAIL', 'INFRASTRUCTURE_INVALID') -contains $Result['outcome'])) {
        return @{ Accepted = $false; Reason = 'invalid_stage_outcome' }
    }

    return @{ Accepted = $true; Reason = 'accepted' }
}

Export-ModuleMember -Function Get-DiscoveryStageConfigFingerprint, New-DiscoveryStageContext, Test-DiscoveryStageResult
