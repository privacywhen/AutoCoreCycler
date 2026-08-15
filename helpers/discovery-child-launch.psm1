Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'discovery-stage.psm1') -Force

function New-DiscoveryStageChildLaunchPlan {
    param(
        [Parameter(Mandatory=$true)] [String] $ChildScriptPath,
        [Parameter(Mandatory=$true)] [String] $StageConfigPath,
        [Parameter(Mandatory=$true)] [Int] $CoreNumber,
        [Parameter(Mandatory=$true)] [Int] $Candidate,
        [Parameter(Mandatory=$true)] [String] $CandidateAttemptId,
        [Parameter(Mandatory=$true)] [String] $StageAttemptId,
        [Parameter(Mandatory=$true)] [String] $WorkloadId,
        [Parameter(Mandatory=$true)] [String] $LogPath
    )

    foreach ($field in @{
        CandidateAttemptId = $CandidateAttemptId
        StageAttemptId     = $StageAttemptId
        WorkloadId         = $WorkloadId
    }.GetEnumerator()) {
        if ([String]::IsNullOrWhiteSpace($field.Value)) {
            throw ('Discovery child launch ' + $field.Key + ' is required.')
        }
    }

    if ($CandidateAttemptId -eq $StageAttemptId) {
        throw 'Discovery child launch candidate and stage attempt IDs must be distinct.'
    }

    $resolvedChildScriptPath = [System.IO.Path]::GetFullPath($ChildScriptPath)
    if (!(Test-Path -LiteralPath $resolvedChildScriptPath -PathType Leaf)) {
        throw 'Discovery child script path does not exist or is not a file.'
    }

    $resolvedStageConfigPath = [System.IO.Path]::GetFullPath($StageConfigPath)
    if (!(Test-Path -LiteralPath $resolvedStageConfigPath -PathType Leaf)) {
        throw 'Discovery child stage config path does not exist or is not a file.'
    }

    $workingDirectory = [System.IO.Path]::GetDirectoryName($resolvedChildScriptPath)
    $rootConfigPath = [System.IO.Path]::GetFullPath((Join-Path $workingDirectory 'config.ini'))
    if ($resolvedStageConfigPath -eq $rootConfigPath) {
        throw 'Discovery child stage config must not be the repository config.ini.'
    }

    $resolvedLogPath = [System.IO.Path]::GetFullPath($LogPath)
    if (Test-Path -LiteralPath $resolvedLogPath) {
        throw 'Discovery child stage log path must be fresh and not already exist.'
    }

    return [PSCustomObject]@{
        FilePath                         = 'powershell.exe'
        ArgumentList                     = @('-ExecutionPolicy', 'Bypass', '-File', $resolvedChildScriptPath, '-ConfigPath', $resolvedStageConfigPath)
        WorkingDirectory                 = $workingDirectory
        Identity                         = @{
            coreNumber         = $CoreNumber
            candidate          = $Candidate
            candidateAttemptId = $CandidateAttemptId
            stageAttemptId     = $StageAttemptId
            workloadId         = $WorkloadId
            configPath         = $resolvedStageConfigPath
            configFingerprint  = Get-DiscoveryStageConfigFingerprint -ConfigPath $resolvedStageConfigPath
            logPath            = $resolvedLogPath
        }
        RequiresObservedProcessIdentity = $true
    }
}

function Resolve-DiscoveryStageChildLaunchPlanContract {
    param(
        [Parameter(Mandatory=$true)] [PSObject] $Plan
    )

    if ($null -eq $Plan) {
        return @{ Valid = $false; Reason = 'invalid_launch_plan' }
    }

    $requiredPlanProperties = @('FilePath', 'ArgumentList', 'WorkingDirectory', 'Identity', 'RequiresObservedProcessIdentity')
    $planPropertyNames = @()
    foreach ($property in $Plan.PSObject.Properties) {
        $planPropertyNames += $property.Name
    }
    foreach ($propertyName in $requiredPlanProperties) {
        if ($planPropertyNames -notcontains $propertyName) {
            return @{ Valid = $false; Reason = 'invalid_launch_plan' }
        }
    }

    if ($Plan.FilePath -isnot [String] -or [String]::IsNullOrWhiteSpace($Plan.FilePath) -or $Plan.FilePath -ne 'powershell.exe' -or $Plan.WorkingDirectory -isnot [String] -or [String]::IsNullOrWhiteSpace($Plan.WorkingDirectory) -or $Plan.ArgumentList -isnot [Array] -or $Plan.Identity -isnot [hashtable] -or !($Plan.RequiresObservedProcessIdentity -is [Bool]) -or $Plan.RequiresObservedProcessIdentity -ne $true) {
        return @{ Valid = $false; Reason = 'invalid_launch_plan' }
    }

    $arguments = @($Plan.ArgumentList)
    if ($arguments.Count -ne 6) {
        return @{ Valid = $false; Reason = 'invalid_launch_plan' }
    }

    foreach ($argument in $arguments) {
        if ($argument -isnot [String] -or [String]::IsNullOrWhiteSpace($argument)) {
            return @{ Valid = $false; Reason = 'invalid_launch_plan' }
        }
    }

    if ($arguments[0] -ne '-ExecutionPolicy' -or $arguments[1] -ne 'Bypass' -or $arguments[2] -ne '-File' -or $arguments[4] -ne '-ConfigPath') {
        return @{ Valid = $false; Reason = 'invalid_launch_plan' }
    }

    $requiredIdentityFields = @('coreNumber', 'candidate', 'candidateAttemptId', 'stageAttemptId', 'workloadId', 'configPath', 'configFingerprint', 'logPath')
    foreach ($field in $requiredIdentityFields) {
        if (!$Plan.Identity.ContainsKey($field) -or $null -eq $Plan.Identity[$field]) {
            return @{ Valid = $false; Reason = 'invalid_launch_plan' }
        }
    }

    if ($Plan.Identity['coreNumber'] -isnot [Int] -or $Plan.Identity['candidate'] -isnot [Int]) {
        return @{ Valid = $false; Reason = 'invalid_launch_plan' }
    }

    foreach ($field in @('candidateAttemptId', 'stageAttemptId', 'workloadId', 'configPath', 'configFingerprint', 'logPath')) {
        if ($Plan.Identity[$field] -isnot [String] -or [String]::IsNullOrWhiteSpace($Plan.Identity[$field])) {
            return @{ Valid = $false; Reason = 'invalid_launch_plan' }
        }
    }

    if ($Plan.Identity['candidateAttemptId'] -eq $Plan.Identity['stageAttemptId']) {
        return @{ Valid = $false; Reason = 'invalid_launch_plan' }
    }

    try {
        $childScriptPath = [System.IO.Path]::GetFullPath($arguments[3])
        $configPath = [System.IO.Path]::GetFullPath($arguments[5])
        $logPath = [System.IO.Path]::GetFullPath($Plan.Identity['logPath'])
        $identityConfigPath = [System.IO.Path]::GetFullPath($Plan.Identity['configPath'])
        $workingDirectory = [System.IO.Path]::GetFullPath($Plan.WorkingDirectory)
        $rootConfigPath = [System.IO.Path]::GetFullPath((Join-Path $workingDirectory 'config.ini'))
    }
    catch {
        return @{ Valid = $false; Reason = 'invalid_launch_plan' }
    }

    if ($identityConfigPath -ne $configPath -or [System.IO.Path]::GetDirectoryName($childScriptPath) -ne $workingDirectory) {
        return @{ Valid = $false; Reason = 'invalid_launch_plan' }
    }

    return @{
        Valid             = $true
        ChildScriptPath   = $childScriptPath
        ConfigPath        = $configPath
        LogPath           = $logPath
        RootConfigPath    = $rootConfigPath
        WorkingDirectory  = $workingDirectory
    }
}

function Test-DiscoveryStageContextMatchesChildLaunchPlan {
    param(
        [Parameter(Mandatory=$true)] [PSObject] $Plan,
        [Parameter(Mandatory=$true)] [hashtable] $Context
    )

    $planContract = Resolve-DiscoveryStageChildLaunchPlanContract -Plan $Plan
    if (!$planContract.Valid) {
        return @{ Matches = $false; Reason = $planContract.Reason }
    }

    $requiredContextFields = @('coreNumber', 'candidate', 'candidateAttemptId', 'stageAttemptId', 'workloadId', 'configPath', 'configFingerprint', 'logPath', 'childProcessId', 'startedAt')
    foreach ($field in $requiredContextFields) {
        if (!$Context.ContainsKey($field) -or $null -eq $Context[$field]) {
            return @{ Matches = $false; Reason = 'invalid_observed_context' }
        }
    }

    if ($Context['coreNumber'] -isnot [Int] -or $Context['candidate'] -isnot [Int] -or $Context['childProcessId'] -isnot [Int] -or $Context['childProcessId'] -lt 1 -or $Context['startedAt'] -isnot [DateTime] -or $Context['startedAt'].Ticks -eq 0 -or $Context['startedAt'].Kind -ne [DateTimeKind]::Utc) {
        return @{ Matches = $false; Reason = 'invalid_observed_context' }
    }

    foreach ($field in @('candidateAttemptId', 'stageAttemptId', 'workloadId', 'configPath', 'configFingerprint', 'logPath')) {
        if ($Context[$field] -isnot [String] -or [String]::IsNullOrWhiteSpace($Context[$field])) {
            return @{ Matches = $false; Reason = 'invalid_observed_context' }
        }
    }

    try {
        $contextConfigPath = [System.IO.Path]::GetFullPath($Context['configPath'])
        $contextLogPath = [System.IO.Path]::GetFullPath($Context['logPath'])
    }
    catch {
        return @{ Matches = $false; Reason = 'invalid_observed_context' }
    }

    if ($Context['coreNumber'] -ne $Plan.Identity['coreNumber'] -or $Context['candidate'] -ne $Plan.Identity['candidate'] -or $Context['candidateAttemptId'] -ne $Plan.Identity['candidateAttemptId'] -or $Context['stageAttemptId'] -ne $Plan.Identity['stageAttemptId'] -or $Context['workloadId'] -ne $Plan.Identity['workloadId'] -or $contextConfigPath -ne $planContract.ConfigPath -or $contextLogPath -ne $planContract.LogPath) {
        return @{ Matches = $false; Reason = 'stage_context_mismatch' }
    }

    try {
        $currentConfigFingerprint = Get-DiscoveryStageConfigFingerprint -ConfigPath $planContract.ConfigPath
    }
    catch {
        return @{ Matches = $false; Reason = 'config_fingerprint_unavailable' }
    }

    if ($Context['configFingerprint'] -ne $Plan.Identity['configFingerprint'] -or $currentConfigFingerprint -ne $Plan.Identity['configFingerprint']) {
        return @{ Matches = $false; Reason = 'config_fingerprint_mismatch' }
    }

    return @{ Matches = $true; Reason = 'matched' }
}

function Test-DiscoveryStageChildLaunchPlanReadiness {
    param(
        [Parameter(Mandatory=$true)] [PSObject] $Plan
    )

    $planContract = Resolve-DiscoveryStageChildLaunchPlanContract -Plan $Plan
    if (!$planContract.Valid) {
        return @{ Ready = $false; Reason = $planContract.Reason }
    }

    if (!(Test-Path -LiteralPath $planContract.ChildScriptPath -PathType Leaf)) {
        return @{ Ready = $false; Reason = 'child_script_unavailable' }
    }

    if ($planContract.ConfigPath -eq $planContract.RootConfigPath) {
        return @{ Ready = $false; Reason = 'root_config_not_allowed' }
    }

    try {
        $currentConfigFingerprint = Get-DiscoveryStageConfigFingerprint -ConfigPath $planContract.ConfigPath
    }
    catch {
        return @{ Ready = $false; Reason = 'config_fingerprint_unavailable' }
    }

    if ($currentConfigFingerprint -ne $Plan.Identity['configFingerprint']) {
        return @{ Ready = $false; Reason = 'config_fingerprint_mismatch' }
    }

    if (Test-Path -LiteralPath $planContract.LogPath) {
        return @{ Ready = $false; Reason = 'stage_log_not_fresh' }
    }

    return @{ Ready = $true; Reason = 'ready' }
}

function Start-DiscoveryStageChildFromPlan {
    param(
        [Parameter(Mandatory=$true)] [PSObject] $Plan
    )

    $readiness = Test-DiscoveryStageChildLaunchPlanReadiness -Plan $Plan
    if (!$readiness.Ready) {
        return [PSCustomObject]@{ Launched = $false; Reason = $readiness.Reason; ChildProcessId = $null; Context = $null }
    }

    try {
        $childProcess = Start-Process -FilePath $Plan.FilePath -ArgumentList $Plan.ArgumentList -WorkingDirectory $Plan.WorkingDirectory -PassThru -ErrorAction Stop
    }
    catch {
        return [PSCustomObject]@{ Launched = $false; Reason = 'child_launch_failed'; ChildProcessId = $null; Context = $null }
    }

    try {
        $candidateProcessId = $childProcess.Id
        if ($candidateProcessId -isnot [Int] -or $candidateProcessId -lt 1) {
            throw 'Child process identity is unavailable.'
        }
        $childProcessId = $candidateProcessId
    }
    catch {
        return [PSCustomObject]@{ Launched = $true; Reason = 'child_process_identity_unavailable'; ChildProcessId = $null; Context = $null }
    }

    try {
        $startedAt = $childProcess.StartTime.ToUniversalTime()
    }
    catch {
        return [PSCustomObject]@{ Launched = $true; Reason = 'child_start_time_unavailable'; ChildProcessId = $childProcessId; Context = $null }
    }

    $observation = New-DiscoveryStageContextFromObservedChild -Plan $Plan -ChildProcessId $childProcessId -StartedAt $startedAt
    if (!$observation.Observed) {
        return [PSCustomObject]@{ Launched = $true; Reason = $observation.Reason; ChildProcessId = $childProcessId; Context = $null }
    }

    return [PSCustomObject]@{ Launched = $true; Reason = 'launched'; ChildProcessId = $childProcessId; Context = $observation.Context }
}

function New-DiscoveryStageContextFromObservedChild {
    param(
        [Parameter(Mandatory=$true)] [PSObject] $Plan,
        [Parameter(Mandatory=$true)] [Object] $ChildProcessId,
        [Parameter(Mandatory=$true)] [Object] $StartedAt
    )

    $planContract = Resolve-DiscoveryStageChildLaunchPlanContract -Plan $Plan
    if (!$planContract.Valid) {
        return [PSCustomObject]@{ Observed = $false; Reason = $planContract.Reason; Context = $null }
    }

    if ($ChildProcessId -isnot [Int] -or $ChildProcessId -lt 1 -or $StartedAt -isnot [DateTime] -or $StartedAt.Ticks -eq 0 -or $StartedAt.Kind -ne [DateTimeKind]::Utc) {
        return [PSCustomObject]@{ Observed = $false; Reason = 'invalid_observed_process_identity'; Context = $null }
    }

    if ($planContract.ConfigPath -eq $planContract.RootConfigPath) {
        return [PSCustomObject]@{ Observed = $false; Reason = 'root_config_not_allowed'; Context = $null }
    }

    try {
        $context = New-DiscoveryStageContext -CoreNumber $Plan.Identity['coreNumber'] -Candidate $Plan.Identity['candidate'] -CandidateAttemptId $Plan.Identity['candidateAttemptId'] -StageAttemptId $Plan.Identity['stageAttemptId'] -WorkloadId $Plan.Identity['workloadId'] -ConfigPath $planContract.ConfigPath -LogPath $planContract.LogPath -ChildProcessId $ChildProcessId -StartedAt $StartedAt
    }
    catch {
        return [PSCustomObject]@{ Observed = $false; Reason = 'config_fingerprint_unavailable'; Context = $null }
    }

    $contextDecision = Test-DiscoveryStageContextMatchesChildLaunchPlan -Plan $Plan -Context $context
    if (!$contextDecision.Matches) {
        return [PSCustomObject]@{ Observed = $false; Reason = $contextDecision.Reason; Context = $null }
    }

    return [PSCustomObject]@{ Observed = $true; Reason = 'observed'; Context = $context }
}

Export-ModuleMember -Function New-DiscoveryStageChildLaunchPlan, Test-DiscoveryStageChildLaunchPlanReadiness, Start-DiscoveryStageChildFromPlan, New-DiscoveryStageContextFromObservedChild
