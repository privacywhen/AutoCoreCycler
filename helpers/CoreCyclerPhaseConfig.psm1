Set-StrictMode -Version 3.0

$Script:CoreCyclerPhaseTypeOrder = @{
    'baselinesanity'             = 10
    'sentinel'                   = 20
    'coarseisolateddiscovery'    = 30
    'fineisolateddiscovery'      = 40
    'combinedmapvalidation'      = 60
    'transitionvalidation'       = 70
    'alternateworkloadvalidation'= 80
}

$Script:CoreCyclerKnownSections = @(
    'General'
    'Prime95'
    'yCruncher'
    'AutomaticTestMode'
    'Logging'
)

$Script:CoreCyclerRyzenGenerationProfiles = @{
    'ryzen5000' = [ordered]@{
        Name                       = 'Ryzen5000'
        DisplayName                = 'Ryzen 5000'
        MinimumCurveOptimizerValue = -30
        Sections                   = [ordered]@{
            Prime95   = [ordered]@{
                mode    = 'SSE'
                FFTSize = 'Huge'
            }
            yCruncher = [ordered]@{
                mode = '19-ZN2 ~ Kagari'
            }
            AutomaticTestMode = [ordered]@{
                maxValue                      = 0
                voltageValueForNotTestedCores = 0
            }
        }
    }
    'ryzen7000' = [ordered]@{
        Name                       = 'Ryzen7000'
        DisplayName                = 'Ryzen 7000'
        MinimumCurveOptimizerValue = -50
        Sections                   = [ordered]@{
            Prime95   = [ordered]@{
                mode    = 'SSE'
                FFTSize = 'Huge'
            }
            yCruncher = [ordered]@{
                mode = '22-ZN4 ~ Kizuna'
            }
            AutomaticTestMode = [ordered]@{
                maxValue                      = 0
                voltageValueForNotTestedCores = 0
            }
        }
    }
    'ryzen8000' = [ordered]@{
        Name                       = 'Ryzen8000'
        DisplayName                = 'Ryzen 8000'
        MinimumCurveOptimizerValue = -50
        Sections                   = [ordered]@{
            Prime95   = [ordered]@{
                mode    = 'SSE'
                FFTSize = 'Huge'
            }
            yCruncher = [ordered]@{
                mode = '22-ZN4 ~ Kizuna'
            }
            AutomaticTestMode = [ordered]@{
                maxValue                      = 0
                voltageValueForNotTestedCores = 0
            }
        }
    }
    'ryzen9000' = [ordered]@{
        Name                       = 'Ryzen9000'
        DisplayName                = 'Ryzen 9000'
        MinimumCurveOptimizerValue = -50
        Sections                   = [ordered]@{
            Prime95   = [ordered]@{
                mode    = 'SSE'
                FFTSize = 'Huge'
            }
            yCruncher = [ordered]@{
                mode = '24-ZN5 ~ Komari'
            }
            AutomaticTestMode = [ordered]@{
                maxValue                      = 0
                voltageValueForNotTestedCores = 0
            }
        }
    }
}

function Get-CoreCyclerMapValue {
    param(
        [Parameter(Mandatory=$false)] $Map,
        [Parameter(Mandatory=$true)] [String] $Key,
        [Parameter(Mandatory=$false)] $Default = $null
    )

    if ($null -eq $Map) {
        return $Default
    }

    if ($Map -is [System.Collections.IDictionary]) {
        if ($Map.Contains($Key)) {
            return $Map[$Key]
        }

        return $Default
    }

    $property = $Map.PSObject.Properties[$Key]

    if ($property) {
        return $property.Value
    }

    return $Default
}

function Get-CoreCyclerMapEntries {
    param(
        [Parameter(Mandatory=$false)] $Map
    )

    if ($null -eq $Map) {
        return @()
    }

    if ($Map -is [System.Collections.IDictionary]) {
        return @($Map.GetEnumerator())
    }

    return @($Map.PSObject.Properties | ForEach-Object {
        [PSCustomObject]@{
            Key   = $_.Name
            Value = $_.Value
        }
    })
}

function Merge-CoreCyclerSection {
    param(
        [Parameter(Mandatory=$true)] $Base,
        [Parameter(Mandatory=$false)] $Override
    )

    $result = [ordered]@{}

    foreach ($entry in (Get-CoreCyclerMapEntries $Base)) {
        $result[$entry.Key] = $entry.Value
    }

    foreach ($entry in (Get-CoreCyclerMapEntries $Override)) {
        $result[$entry.Key] = $entry.Value
    }

    return $result
}

function Get-CoreCyclerRyzenGenerationProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [ValidateNotNullOrEmpty()] [String] $RyzenGeneration
    )

    $profileKey = $RyzenGeneration.ToLowerInvariant()

    if (!$Script:CoreCyclerRyzenGenerationProfiles.ContainsKey($profileKey)) {
        throw('Unknown Ryzen generation profile: ' + $RyzenGeneration)
    }

    return $Script:CoreCyclerRyzenGenerationProfiles[$profileKey]
}

function Merge-CoreCyclerProfileDefaults {
    param(
        [Parameter(Mandatory=$true)] $Defaults,
        [Parameter(Mandatory=$true)] $Profile
    )

    $profileSections = Get-CoreCyclerMapValue $Profile 'Sections'
    $mergedDefaults = [ordered]@{}

    foreach ($sectionName in $Script:CoreCyclerKnownSections) {
        $baseSection = Get-CoreCyclerMapValue $Defaults $sectionName ([ordered]@{})
        $profileSection = Get-CoreCyclerMapValue $profileSections $sectionName $null
        $mergedDefaults[$sectionName] = Merge-CoreCyclerSection $baseSection $profileSection
    }

    return $mergedDefaults
}

function Get-CoreCyclerPhaseRank {
    param(
        [Parameter(Mandatory=$true)] [String] $Type
    )

    $key = $Type.ToLowerInvariant()

    if (!$Script:CoreCyclerPhaseTypeOrder.ContainsKey($key)) {
        throw('Unknown CoreCycler phase type: ' + $Type)
    }

    return [Int] $Script:CoreCyclerPhaseTypeOrder[$key]
}

function Get-CoreCyclerPhaseDefaults {
    param(
        [Parameter(Mandatory=$true)] [String] $Type
    )

    $null = Get-CoreCyclerPhaseRank $Type

    $general = [ordered]@{
        stressTestProgram          = 'PRIME95'
        runtimePerCore             = '10m'
        suspendPeriodically        = 1
        coreTestOrder              = 'Default'
        skipCoreOnError            = 1
        stopOnError                = 0
        numberOfThreads            = 1
        maxIterations              = 1
        restartTestProgramForEachCore = 0
        delayBetweenCores          = 15
        lookForWheaErrors          = 1
        treatWheaWarningAsError    = 1
    }

    $prime95 = [ordered]@{
        mode    = 'SSE'
        FFTSize = 'Huge'
    }

    $yCruncher = [ordered]@{
        mode                         = 'auto'
        tests                        = 'SFTv4, FFTv4, N63'
        testDuration                 = 20
        enableYCruncherLoggingWrapper = 1
    }

    $automaticTestMode = [ordered]@{
        enableAutomaticAdjustment       = 0
        startValues                     = 'CurrentValues'
        maxValue                        = 0
        incrementBy                     = 'Default'
        setVoltageOnlyForTestedCore     = 0
        voltageValueForNotTestedCores   = 0
        repeatCoreOnError               = 1
        enableResumeAfterUnexpectedExit = 0
        createSystemRestorePoint        = 1
        askForSystemRestorePointCreation = 1
    }

    $logging = [ordered]@{
        name               = 'CoreCycler'
        useWindowsEventLog = 1
    }

    switch ($Type.ToLowerInvariant()) {
        'baselinesanity' {
            $general.runtimePerCore = '10m'
            $general.coreTestOrder = 'Default'
        }

        'sentinel' {
            $general.runtimePerCore = '10m'
            $general.coreTestOrder = 'Default'
        }

        'coarseisolateddiscovery' {
            $general.runtimePerCore = '6m'
            $automaticTestMode.enableAutomaticAdjustment = 1
            $automaticTestMode.incrementBy = 3
            $automaticTestMode.setVoltageOnlyForTestedCore = 1
            $automaticTestMode.voltageValueForNotTestedCores = 0
        }

        'fineisolateddiscovery' {
            $general.runtimePerCore = '12m'
            $automaticTestMode.enableAutomaticAdjustment = 1
            $automaticTestMode.incrementBy = 1
            $automaticTestMode.setVoltageOnlyForTestedCore = 1
            $automaticTestMode.voltageValueForNotTestedCores = 0
        }

        'combinedmapvalidation' {
            $general.runtimePerCore = '30m'
            $automaticTestMode.enableAutomaticAdjustment = 0
            $automaticTestMode.setVoltageOnlyForTestedCore = 0
        }

        'transitionvalidation' {
            $general.runtimePerCore = '10m'
            $general.coreTestOrder = 'CorePairs'
            $general.suspendPeriodically = 1
            $automaticTestMode.enableAutomaticAdjustment = 0
            $automaticTestMode.setVoltageOnlyForTestedCore = 0
        }

        'alternateworkloadvalidation' {
            $general.stressTestProgram = 'YCRUNCHER'
            $general.runtimePerCore = 'auto'
            $general.restartTestProgramForEachCore = 1
            $general.delayBetweenCores = 5
            $automaticTestMode.enableAutomaticAdjustment = 0
            $automaticTestMode.setVoltageOnlyForTestedCore = 0
        }
    }

    return [ordered]@{
        General           = $general
        Prime95           = $prime95
        yCruncher         = $yCruncher
        AutomaticTestMode = $automaticTestMode
        Logging           = $logging
    }
}

function Test-CoreCyclerPositiveCurveOptimizerValue {
    param(
        [Parameter(Mandatory=$false)] $Value
    )

    if ($null -eq $Value) {
        return $false
    }

    if ($Value -is [Array]) {
        foreach ($entry in $Value) {
            if (Test-CoreCyclerPositiveCurveOptimizerValue $entry) {
                return $true
            }
        }

        return $false
    }

    if ($Value -is [Int] -or $Value -is [Int16] -or $Value -is [Int32] -or $Value -is [Int64]) {
        return ([Int] $Value -gt 0)
    }

    $valueString = ([String] $Value).Trim()

    if ([String]::IsNullOrWhiteSpace($valueString)) {
        return $false
    }

    if ($valueString.ToLowerInvariant() -in @('currentvalues', 'default', 'minimum')) {
        return $false
    }

    $parts = @($valueString -Split '\s*[,\|]\s*|\s+' | Where-Object { $_.Length -gt 0 })

    foreach ($part in $parts) {
        if ($part -Match '^\-?\d+$' -and [Int] $part -gt 0) {
            return $true
        }
    }

    return $false
}

function Get-CoreCyclerCurveOptimizerNumericValues {
    param(
        [Parameter(Mandatory=$false)] $Value
    )

    if ($null -eq $Value) {
        return @()
    }

    if ($Value -is [Array]) {
        $values = @()

        foreach ($entry in $Value) {
            $values += Get-CoreCyclerCurveOptimizerNumericValues $entry
        }

        return $values
    }

    if ($Value -is [Int] -or $Value -is [Int16] -or $Value -is [Int32] -or $Value -is [Int64]) {
        return @([Int] $Value)
    }

    $valueString = ([String] $Value).Trim()

    if ([String]::IsNullOrWhiteSpace($valueString)) {
        return @()
    }

    if ($valueString.ToLowerInvariant() -in @('currentvalues', 'default', 'minimum')) {
        return @()
    }

    $parts = @($valueString -Split '\s*[,\|]\s*|\s+' | Where-Object { $_.Length -gt 0 })

    return @($parts | Where-Object { $_ -Match '^\-?\d+$' } | ForEach-Object { [Int] $_ })
}

function Test-CoreCyclerMapContainsKey {
    param(
        [Parameter(Mandatory=$false)] $Map,
        [Parameter(Mandatory=$true)] [String] $Key
    )

    if ($null -eq $Map) {
        return $false
    }

    if ($Map -is [System.Collections.IDictionary]) {
        return $Map.Contains($Key)
    }

    return ($null -ne $Map.PSObject.Properties[$Key])
}

function ConvertTo-CoreCyclerCurveOptimizerValueArray {
    param(
        [Parameter(Mandatory=$false)] $Value,
        [Parameter(Mandatory=$false)] [String] $Description = 'Curve Optimizer map'
    )

    if ($null -eq $Value) {
        throw($Description + ' cannot be empty.')
    }

    if ($Value -is [Array]) {
        $values = @()

        foreach ($entry in $Value) {
            $values += ConvertTo-CoreCyclerCurveOptimizerValueArray -Value $entry -Description $Description
        }

        if ($values.Count -lt 1) {
            throw($Description + ' cannot be empty.')
        }

        return @($values)
    }

    if ($Value -is [Int] -or $Value -is [Int16] -or $Value -is [Int32] -or $Value -is [Int64]) {
        return @([Int] $Value)
    }

    $valueString = ([String] $Value).Trim()

    if ([String]::IsNullOrWhiteSpace($valueString)) {
        throw($Description + ' cannot be empty.')
    }

    $parts = @($valueString -Split '\s*[,\|]\s*|\s+' | Where-Object { $_.Length -gt 0 })

    if ($parts.Count -lt 1) {
        throw($Description + ' cannot be empty.')
    }

    $values = @()

    foreach ($part in $parts) {
        if ($part -NotMatch '^\-?\d+$') {
            throw($Description + ' contains a non-integer value: ' + $part)
        }

        $values += [Int] $part
    }

    return @($values)
}

function Resolve-CoreCyclerCandidateCurveOptimizerMap {
    param(
        [Parameter(Mandatory=$true)] $CandidateMap
    )

    $mapSource = $CandidateMap

    if (Test-CoreCyclerMapContainsKey -Map $CandidateMap -Key 'CandidateMap') {
        $mapSource = Get-CoreCyclerMapValue $CandidateMap 'CandidateMap'
    }

    return @(ConvertTo-CoreCyclerCurveOptimizerValueArray -Value $mapSource -Description 'Candidate Curve Optimizer map')
}

function Get-CoreCyclerSummaryInstabilityReasons {
    param(
        [Parameter(Mandatory=$true)] $Summary
    )

    $reasons = @()
    $coresWithErrors = @(Get-CoreCyclerMapValue $Summary 'CoresWithErrors' @())
    $errorDetails = @(Get-CoreCyclerMapValue $Summary 'ErrorDetails' @())
    $whea = Get-CoreCyclerMapValue $Summary 'Whea' $null
    $wheaTotalCount = 0

    if ($whea) {
        $wheaTotalCount = [Int] (Get-CoreCyclerMapValue $whea 'TotalCount' 0)
    }

    if ($coresWithErrors.Count -gt 0) {
        $reasons += 'cores with errors: ' + ($coresWithErrors -Join ', ')
    }

    if ($errorDetails.Count -gt 0) {
        $errorTypes = @($errorDetails | ForEach-Object { Get-CoreCyclerMapValue $_ 'ErrorType' } | Where-Object { ![String]::IsNullOrWhiteSpace([String] $_) } | Sort-Object -Unique)
        $detailText = $(if ($errorTypes.Count -gt 0) { $errorTypes -Join ', ' } else { $errorDetails.Count.ToString() + ' error detail entries' })
        $reasons += 'error details: ' + $detailText
    }

    if ($wheaTotalCount -gt 0) {
        $reasons += 'WHEA count: ' + $wheaTotalCount
    }

    return @($reasons)
}

function Assert-CoreCyclerNoPositiveCurveOptimizer {
    param(
        [Parameter(Mandatory=$true)] $Sections
    )

    $automaticTestMode = Get-CoreCyclerMapValue $Sections 'AutomaticTestMode'

    foreach ($settingName in @('maxValue', 'voltageValueForNotTestedCores', 'startValues')) {
        $settingValue = Get-CoreCyclerMapValue $automaticTestMode $settingName

        if (Test-CoreCyclerPositiveCurveOptimizerValue $settingValue) {
            throw('Positive Curve Optimizer value found in AutomaticTestMode.' + $settingName + '. Use -AllowPositiveCurveOptimizer only for explicit positive CO opt-in.')
        }
    }
}

function Assert-CoreCyclerAutomaticTestModeBounds {
    param(
        [Parameter(Mandatory=$true)] $Sections,
        [Parameter(Mandatory=$false)] $Profile = $null
    )

    $automaticTestMode = Get-CoreCyclerMapValue $Sections 'AutomaticTestMode'
    $maxValue = Get-CoreCyclerMapValue $automaticTestMode 'maxValue'

    if ($null -eq $maxValue -or ([String] $maxValue) -NotMatch '^\-?\d+$') {
        throw('AutomaticTestMode.maxValue must be an integer and must default to 0 for Ryzen CO automation.')
    }

    if ($null -eq $Profile) {
        return
    }

    $minimumCurveOptimizerValue = [Int] (Get-CoreCyclerMapValue $Profile 'MinimumCurveOptimizerValue')

    foreach ($settingName in @('startValues', 'voltageValueForNotTestedCores')) {
        foreach ($coValue in (Get-CoreCyclerCurveOptimizerNumericValues (Get-CoreCyclerMapValue $automaticTestMode $settingName))) {
            if ($coValue -lt $minimumCurveOptimizerValue) {
                $displayName = Get-CoreCyclerMapValue $Profile 'DisplayName'
                throw('Curve Optimizer value ' + $coValue + ' in AutomaticTestMode.' + $settingName + ' is below the ' + $displayName + ' profile minimum of ' + $minimumCurveOptimizerValue + '.')
            }
        }
    }
}

function Get-CoreCyclerNormalizedPhase {
    param(
        [Parameter(Mandatory=$true)] $Phase,
        [Parameter(Mandatory=$false)] [Switch] $AllowPositiveCurveOptimizer
    )

    $name = Get-CoreCyclerMapValue $Phase 'Name'
    $type = Get-CoreCyclerMapValue $Phase 'Type'
    $order = Get-CoreCyclerMapValue $Phase 'Order'
    $ryzenGeneration = Get-CoreCyclerMapValue $Phase 'RyzenGeneration'

    if ([String]::IsNullOrWhiteSpace([String] $name)) {
        throw('CoreCycler phase requires a non-empty Name.')
    }

    if ([String]::IsNullOrWhiteSpace([String] $type)) {
        throw('CoreCycler phase requires a non-empty Type.')
    }

    $rank = Get-CoreCyclerPhaseRank $type

    if ($null -eq $order -or [String]::IsNullOrWhiteSpace([String] $order)) {
        $order = $rank
    }

    if (([String] $order) -NotMatch '^\d+$' -or [Int] $order -lt 1) {
        throw('CoreCycler phase Order must be a positive integer.')
    }

    $profile = $null
    $defaults = Get-CoreCyclerPhaseDefaults $type

    if (![String]::IsNullOrWhiteSpace([String] $ryzenGeneration)) {
        $profile = Get-CoreCyclerRyzenGenerationProfile $ryzenGeneration
        $defaults = Merge-CoreCyclerProfileDefaults -Defaults $defaults -Profile $profile
        $ryzenGeneration = Get-CoreCyclerMapValue $profile 'Name'
    }

    $phaseSections = Get-CoreCyclerMapValue $Phase 'Sections' ([ordered]@{})

    foreach ($entry in (Get-CoreCyclerMapEntries $phaseSections)) {
        if ($Script:CoreCyclerKnownSections -notcontains $entry.Key) {
            throw('Unknown CoreCycler phase section: ' + $entry.Key)
        }
    }

    $sections = [ordered]@{}

    foreach ($sectionName in $Script:CoreCyclerKnownSections) {
        $sectionOverride = Get-CoreCyclerMapValue $phaseSections $sectionName $null
        $topLevelOverride = Get-CoreCyclerMapValue $Phase $sectionName $null
        $merged = Merge-CoreCyclerSection (Get-CoreCyclerMapValue $defaults $sectionName) $sectionOverride
        $sections[$sectionName] = Merge-CoreCyclerSection $merged $topLevelOverride
    }

    Assert-CoreCyclerAutomaticTestModeBounds -Sections $sections -Profile $profile

    if (!$AllowPositiveCurveOptimizer.IsPresent) {
        Assert-CoreCyclerNoPositiveCurveOptimizer $sections
    }

    return [ordered]@{
        SchemaVersion = $(Get-CoreCyclerMapValue $Phase 'SchemaVersion' 1)
        Name          = [String] $name
        Type          = [String] $type
        Order         = [Int] $order
        Rank          = [Int] $rank
        RyzenGeneration = $(if ($profile) { [String] $ryzenGeneration } else { $null })
        Profile       = $profile
        Sections      = $sections
    }
}

function Format-CoreCyclerIniValue {
    param(
        [Parameter(Mandatory=$false)] $Value
    )

    if ($null -eq $Value) {
        return ''
    }

    if ($Value -is [Boolean]) {
        if ($Value) {
            return '1'
        }

        return '0'
    }

    if ($Value -is [Array]) {
        return (($Value | ForEach-Object { [String] $_ }) -Join ', ')
    }

    $text = [String] $Value

    if ($text -Match "\r|\n") {
        throw('INI values must be single-line strings.')
    }

    return $text
}

function Add-CoreCyclerIniSection {
    param(
        [Parameter(Mandatory=$true)] [System.Collections.ArrayList] $Lines,
        [Parameter(Mandatory=$true)] [String] $Name,
        [Parameter(Mandatory=$true)] $Settings
    )

    [Void] $Lines.Add('')
    [Void] $Lines.Add('[' + $Name + ']')

    foreach ($entry in (Get-CoreCyclerMapEntries $Settings)) {
        [Void] $Lines.Add($entry.Key + ' = ' + (Format-CoreCyclerIniValue $entry.Value))
    }
}

function New-CoreCyclerPhase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [ValidateNotNullOrEmpty()] [String] $Name,
        [Parameter(Mandatory=$true)]
        [ValidateSet('BaselineSanity', 'Sentinel', 'CoarseIsolatedDiscovery', 'FineIsolatedDiscovery', 'CombinedMapValidation', 'TransitionValidation', 'AlternateWorkloadValidation')]
        [String] $Type,
        [Parameter(Mandatory=$false)] [Int] $Order = 0,
        [Parameter(Mandatory=$false)]
        [ValidateSet('Ryzen5000', 'Ryzen7000', 'Ryzen8000', 'Ryzen9000')]
        [String] $RyzenGeneration,
        [Parameter(Mandatory=$false)] $Sections = $null
    )

    if ($Order -lt 1) {
        $Order = Get-CoreCyclerPhaseRank $Type
    }

    if ($null -eq $Sections) {
        $Sections = [ordered]@{}
    }

    return [ordered]@{
        SchemaVersion = 1
        Name          = $Name
        Type          = $Type
        Order         = $Order
        RyzenGeneration = $RyzenGeneration
        Sections      = $Sections
    }
}

function ConvertTo-CoreCyclerIni {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] $Phase,
        [Parameter(Mandatory=$false)] [Switch] $AllowPositiveCurveOptimizer
    )

    $normalized = Get-CoreCyclerNormalizedPhase -Phase $Phase -AllowPositiveCurveOptimizer:$AllowPositiveCurveOptimizer
    $sections = $normalized.Sections
    $general = Get-CoreCyclerMapValue $sections 'General'
    $stressTestProgram = ([String] (Get-CoreCyclerMapValue $general 'stressTestProgram' 'PRIME95')).ToLowerInvariant()
    $lines = [System.Collections.ArrayList]::new()

    [Void] $lines.Add('# Generated CoreCycler phase config')
    [Void] $lines.Add('# PhaseName = ' + $normalized.Name)
    [Void] $lines.Add('# PhaseType = ' + $normalized.Type)
    [Void] $lines.Add('# PhaseOrder = ' + $normalized.Order)

    if ($normalized.RyzenGeneration) {
        [Void] $lines.Add('# RyzenGeneration = ' + $normalized.RyzenGeneration)
        [Void] $lines.Add('# RyzenMinimumCurveOptimizer = ' + (Get-CoreCyclerMapValue $normalized.Profile 'MinimumCurveOptimizerValue'))
    }

    [Void] $lines.Add('# Review before use. SMU-applied Curve Optimizer values are temporary unless persisted elsewhere.')

    $candidateMap = Get-CoreCyclerMapValue $Phase 'CandidateMap' $null
    $mapApplication = Get-CoreCyclerMapValue $Phase 'MapApplication' $null

    if ($null -ne $candidateMap) {
        [Void] $lines.Add('# CandidateMap = ' + (Format-CoreCyclerIniValue $candidateMap))
    }

    if (![String]::IsNullOrWhiteSpace([String] $mapApplication)) {
        [Void] $lines.Add('# MapApplication = ' + (Format-CoreCyclerIniValue $mapApplication))
    }

    if ($AllowPositiveCurveOptimizer.IsPresent) {
        [Void] $lines.Add('# WARNING: Positive Curve Optimizer values were explicitly allowed for this generated config.')
    }

    Add-CoreCyclerIniSection -Lines $lines -Name 'General' -Settings $general

    switch ($stressTestProgram) {
        'prime95' {
            Add-CoreCyclerIniSection -Lines $lines -Name 'Prime95' -Settings (Get-CoreCyclerMapValue $sections 'Prime95')
        }

        'ycruncher' {
            Add-CoreCyclerIniSection -Lines $lines -Name 'yCruncher' -Settings (Get-CoreCyclerMapValue $sections 'yCruncher')
        }

        'y-cruncher' {
            Add-CoreCyclerIniSection -Lines $lines -Name 'yCruncher' -Settings (Get-CoreCyclerMapValue $sections 'yCruncher')
        }

        default {
            throw('The offline phase config generator currently supports PRIME95 and YCRUNCHER phase configs, not: ' + $stressTestProgram)
        }
    }

    Add-CoreCyclerIniSection -Lines $lines -Name 'AutomaticTestMode' -Settings (Get-CoreCyclerMapValue $sections 'AutomaticTestMode')
    Add-CoreCyclerIniSection -Lines $lines -Name 'Logging' -Settings (Get-CoreCyclerMapValue $sections 'Logging')

    return (($lines -Join [Environment]::NewLine) + [Environment]::NewLine)
}

function Export-CoreCyclerPhaseConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] $Phase,
        [Parameter(Mandatory=$true)] [String] $OutputPath,
        [Parameter(Mandatory=$false)] [Switch] $AllowPositiveCurveOptimizer
    )

    $ini = ConvertTo-CoreCyclerIni -Phase $Phase -AllowPositiveCurveOptimizer:$AllowPositiveCurveOptimizer
    $resolvedOutputPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
    $parentPath = Split-Path -Parent $resolvedOutputPath

    if (![String]::IsNullOrWhiteSpace($parentPath) -and !(Test-Path -LiteralPath $parentPath -PathType Container)) {
        $null = New-Item -ItemType Directory -Path $parentPath -Force
    }

    [System.IO.File]::WriteAllText($resolvedOutputPath, $ini, [System.Text.UTF8Encoding]::new($false))

    return Get-Item -LiteralPath $resolvedOutputPath
}

function Test-CoreCyclerPhaseSequence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [Object[]] $Phases
    )

    if ($Phases.Count -lt 1) {
        throw('At least one phase is required.')
    }

    $seenOrders = @{}
    $phaseInfos = @()

    foreach ($phase in $Phases) {
        $normalized = Get-CoreCyclerNormalizedPhase -Phase $phase

        if ($seenOrders.ContainsKey($normalized.Order)) {
            throw('Duplicate CoreCycler phase Order found: ' + $normalized.Order)
        }

        $seenOrders[$normalized.Order] = $true
        $phaseInfos += [PSCustomObject]@{
            Name  = $normalized.Name
            Type  = $normalized.Type
            Order = $normalized.Order
            Rank  = $normalized.Rank
        }
    }

    $lastRank = -1

    foreach ($phaseInfo in ($phaseInfos | Sort-Object -Property Order)) {
        if ($phaseInfo.Rank -lt $lastRank) {
            throw('Invalid phase order: ' + $phaseInfo.Type + ' appears after a later tuning phase.')
        }

        $lastRank = $phaseInfo.Rank
    }

    return $true
}

function ConvertFrom-CoreCyclerPipeSeparatedIntegers {
    param(
        [Parameter(Mandatory=$true)] [String] $Line
    )

    return @($Line -Split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ -Match '^\-?\d+$' } | ForEach-Object { [Int] $_ })
}

function ConvertFrom-CoreCyclerCoreHeader {
    param(
        [Parameter(Mandatory=$true)] [String] $Line
    )

    return @($Line -Split '\|' | ForEach-Object { $_.Trim() } | Where-Object { $_ -Match '^C(\d+)$' } | ForEach-Object { [Int] $Matches[1] })
}

function ConvertFrom-CoreCyclerCoreList {
    param(
        [Parameter(Mandatory=$false)] [String] $Text
    )

    if ([String]::IsNullOrWhiteSpace($Text)) {
        return @()
    }

    return @($Text -Split '\s*,\s*' | Where-Object { $_ -Match '^\d+$' } | ForEach-Object { [Int] $_ })
}

function ConvertFrom-CoreCyclerWheaCoreList {
    param(
        [Parameter(Mandatory=$false)] [String] $Text
    )

    $entries = @()

    if ([String]::IsNullOrWhiteSpace($Text)) {
        return $entries
    }

    foreach ($match in [Regex]::Matches($Text, 'Core\s+(\d+)\s+\((\d+)x\)')) {
        $entries += [PSCustomObject]@{
            Core  = [Int] $match.Groups[1].Value
            Count = [Int] $match.Groups[2].Value
        }
    }

    return $entries
}

function ConvertFrom-CoreCyclerSummaryText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] [String] $Text
    )

    $lines = @($Text -Split '\r?\n')
    $coresWithErrors = @()
    $errorDetails = @()
    $wheaEntries = @()
    $curveOptimizer = [ordered]@{
        Found          = $false
        Adjusted       = $false
        Cores          = @()
        StartingValues = @()
        CurrentValues  = @()
        FinalValues    = @()
    }

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i].TrimEnd()

        if ($line -Match '^ - ([\d,\s]+)$') {
            $coreListText = $Matches[1]
            $previousLine = $(if ($i -gt 0) { $lines[$i - 1].Trim() } else { '' })

            if ($previousLine -Match '^The following cores? ha(?:s|ve) thrown an error:') {
                $coresWithErrors = ConvertFrom-CoreCyclerCoreList $coreListText
            }
        }

        if ($line -Match '^Core\s+(\d+)\s+\|\s+CPU\s+(.+?)\s+\|\s+(.+?)\s+\|\s+([A-Z_]+)\s*$') {
            $detail = [ordered]@{
                Core            = [Int] $Matches[1]
                Cpu             = $Matches[2].Trim()
                Date            = $Matches[3].Trim()
                ErrorType       = $Matches[4].Trim()
                StressTestError = $null
                ErrorMessage    = $null
            }

            if ($i + 1 -lt $lines.Count -and $lines[$i + 1].TrimStart() -Match '^\-\s+(.+)$') {
                $detail.StressTestError = $Matches[1].Trim()
            }

            if ($i + 2 -lt $lines.Count) {
                $possibleMessage = $lines[$i + 2].Trim()

                if (
                    ![String]::IsNullOrWhiteSpace($possibleMessage) -and
                    $possibleMessage -NotMatch '^Core\s+\d+\s+\|' -and
                    $possibleMessage -NotMatch '^There ha(?:s|ve) been WHEA errors?' -and
                    $possibleMessage -NotMatch '^No WHEA errors'
                ) {
                    $detail.ErrorMessage = $possibleMessage
                }
            }

            $errorDetails += [PSCustomObject] $detail
        }

        if ($line.Trim() -Match '^-\s+(.+)$') {
            $wheaListText = $Matches[1]
            $previousLine = $(if ($i -gt 0) { $lines[$i - 1].Trim() } else { '' })

            if ($previousLine -Match '^There ha(?:s|ve) been WHEA errors? while testing:') {
                $wheaEntries = ConvertFrom-CoreCyclerWheaCoreList $wheaListText
            }
        }

        if ($line.Trim() -eq 'There have been adjustments to the Curve Optimizer values:') {
            $curveOptimizer.Found = $true
            $curveOptimizer.Adjusted = $true

            for ($tableIndex = $i + 1; $tableIndex -lt [Math]::Min($i + 6, $lines.Count); $tableIndex++) {
                $tableLine = $lines[$tableIndex].TrimEnd()

                if ($tableLine -Match '^Core\s+(.+)$') {
                    $curveOptimizer.Cores = ConvertFrom-CoreCyclerCoreHeader $Matches[1]
                }
                elseif ($tableLine -Match '^Starting values\s+(.+)$') {
                    $curveOptimizer.StartingValues = ConvertFrom-CoreCyclerPipeSeparatedIntegers $Matches[1]
                }
                elseif ($tableLine -Match '^Current values\s+(.+)$') {
                    $curveOptimizer.CurrentValues = ConvertFrom-CoreCyclerPipeSeparatedIntegers $Matches[1]
                    $curveOptimizer.FinalValues = $curveOptimizer.CurrentValues
                }
            }
        }

        if ($line.Trim() -eq 'No adjustments to the Curve Optimizer values were necessary') {
            $curveOptimizer.Found = $true
            $curveOptimizer.Adjusted = $false

            for ($tableIndex = $i + 1; $tableIndex -lt [Math]::Min($i + 5, $lines.Count); $tableIndex++) {
                $tableLine = $lines[$tableIndex].TrimEnd()

                if ($tableLine -Match '^Core\s+(.+)$') {
                    $curveOptimizer.Cores = ConvertFrom-CoreCyclerCoreHeader $Matches[1]
                }
                elseif ($tableLine -Match '^CO values\s+(.+)$') {
                    $curveOptimizer.StartingValues = ConvertFrom-CoreCyclerPipeSeparatedIntegers $Matches[1]
                    $curveOptimizer.CurrentValues = $curveOptimizer.StartingValues
                    $curveOptimizer.FinalValues = $curveOptimizer.StartingValues
                }
            }
        }
    }

    $wheaTotal = 0

    foreach ($entry in $wheaEntries) {
        $wheaTotal += $entry.Count
    }

    return [PSCustomObject]@{
        CoresWithErrors = @($coresWithErrors | Sort-Object)
        ErrorDetails    = @($errorDetails)
        Whea            = [PSCustomObject]@{
            Cores      = @($wheaEntries)
            TotalCount = [Int] $wheaTotal
        }
        CurveOptimizer  = [PSCustomObject] $curveOptimizer
    }
}

function Get-CoreCyclerCandidateCurveOptimizerMap {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] $Summary,
        [Parameter(Mandatory=$false)] [ValidateRange(0, 100)] [Int] $SafetyMargin = 2,
        [Parameter(Mandatory=$false)] [Int] $MaximumValue = 0,
        [Parameter(Mandatory=$false)] [Switch] $AllowPositiveCurveOptimizer,
        [Parameter(Mandatory=$false)] [Switch] $AllowUnstableSummary
    )

    if ($MaximumValue -gt 0 -and !$AllowPositiveCurveOptimizer.IsPresent) {
        throw('Positive Curve Optimizer output requires -AllowPositiveCurveOptimizer.')
    }

    if (!$Summary.CurveOptimizer -or !$Summary.CurveOptimizer.Found) {
        throw('No Curve Optimizer map was found in the parsed summary.')
    }

    $instabilityReasons = @(Get-CoreCyclerSummaryInstabilityReasons -Summary $Summary)

    if ($instabilityReasons.Count -gt 0 -and !$AllowUnstableSummary.IsPresent) {
        throw('Cannot recommend a candidate daily Curve Optimizer map from an unstable summary: ' + ($instabilityReasons -Join '; ') + '. Resolve the instability and retest, or use -AllowUnstableSummary only for diagnostic workflows.')
    }

    $edgeMap = @($Summary.CurveOptimizer.FinalValues)

    if ($edgeMap.Count -lt 1) {
        throw('The parsed Curve Optimizer map did not contain any values.')
    }

    $candidateMap = @()
    $clampedCores = @()

    for ($i = 0; $i -lt $edgeMap.Count; $i++) {
        $edgeValue = [Int] $edgeMap[$i]
        $candidateValue = $edgeValue + $SafetyMargin
        $effectiveMaximumValue = $(if ($AllowPositiveCurveOptimizer.IsPresent) { $MaximumValue } else { [Math]::Min($MaximumValue, 0) })

        if ($candidateValue -gt $effectiveMaximumValue) {
            $candidateValue = $effectiveMaximumValue
            $clampedCores += $i
        }

        if ($candidateValue -lt $edgeValue) {
            throw('Safety margin calculation made a Curve Optimizer value more negative, which is not allowed.')
        }

        if ($candidateValue -gt 0 -and !$AllowPositiveCurveOptimizer.IsPresent) {
            throw('Positive Curve Optimizer output requires -AllowPositiveCurveOptimizer.')
        }

        $candidateMap += [Int] $candidateValue
    }

    return [PSCustomObject]@{
        EdgeMap                      = @($edgeMap | ForEach-Object { [Int] $_ })
        CandidateMap                 = @($candidateMap)
        SafetyMargin                 = [Int] $SafetyMargin
        MaximumValue                 = [Int] $MaximumValue
        AllowPositiveCurveOptimizer  = [Bool] $AllowPositiveCurveOptimizer.IsPresent
        AllowUnstableSummary         = [Bool] $AllowUnstableSummary.IsPresent
        InstabilityReasons           = @($instabilityReasons)
        ClampedCores                 = @($clampedCores)
    }
}

function New-CoreCyclerCombinedMapValidationPhase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] $CandidateMap,
        [Parameter(Mandatory=$false)] [ValidateNotNullOrEmpty()] [String] $Name = 'combined-map-validation',
        [Parameter(Mandatory=$false)] [Int] $Order = 0,
        [Parameter(Mandatory=$false)]
        [ValidateSet('', 'Ryzen5000', 'Ryzen7000', 'Ryzen8000', 'Ryzen9000')]
        [String] $RyzenGeneration = '',
        [Parameter(Mandatory=$false)] [Int] $ExpectedCoreCount = 0,
        [Parameter(Mandatory=$false)] $Sections = $null,
        [Parameter(Mandatory=$false)] [Switch] $AllowPositiveCurveOptimizer
    )

    if ($ExpectedCoreCount -lt 0) {
        throw('ExpectedCoreCount cannot be negative.')
    }

    $candidateValues = @(Resolve-CoreCyclerCandidateCurveOptimizerMap -CandidateMap $CandidateMap)

    if ($candidateValues.Count -lt 1) {
        throw('Candidate Curve Optimizer map cannot be empty.')
    }

    if ($ExpectedCoreCount -gt 0 -and $candidateValues.Count -ne $ExpectedCoreCount) {
        throw('Candidate Curve Optimizer map contains ' + $candidateValues.Count + ' values, expected ' + $ExpectedCoreCount + '.')
    }

    if (!$AllowPositiveCurveOptimizer.IsPresent -and (Test-CoreCyclerPositiveCurveOptimizerValue $candidateValues)) {
        throw('Positive Curve Optimizer value found in candidate daily map. Use -AllowPositiveCurveOptimizer only for explicit positive CO opt-in.')
    }

    $phaseSections = [ordered]@{}

    foreach ($entry in (Get-CoreCyclerMapEntries $Sections)) {
        $phaseSections[$entry.Key] = $entry.Value
    }

    $automaticTestMode = Get-CoreCyclerMapValue $phaseSections 'AutomaticTestMode' ([ordered]@{})
    $phaseSections['AutomaticTestMode'] = Merge-CoreCyclerSection $automaticTestMode ([ordered]@{
        enableAutomaticAdjustment       = 0
        startValues                     = @($candidateValues)
        maxValue                        = 0
        setVoltageOnlyForTestedCore     = 0
        voltageValueForNotTestedCores   = 0
        enableResumeAfterUnexpectedExit = 0
    })

    if ([String]::IsNullOrWhiteSpace($RyzenGeneration)) {
        $phase = New-CoreCyclerPhase -Name $Name -Type CombinedMapValidation -Order $Order -Sections $phaseSections
    }
    else {
        $phase = New-CoreCyclerPhase -Name $Name -Type CombinedMapValidation -Order $Order -RyzenGeneration $RyzenGeneration -Sections $phaseSections
    }
    $phase['CandidateMap'] = @($candidateValues)
    $phase['MapApplication'] = 'Candidate map must already be active before validation; with enableAutomaticAdjustment = 0, CoreCycler will not apply startValues.'

    return $phase
}

function New-CoreCyclerTransitionValidationPhase {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)] $CandidateMap,
        [Parameter(Mandatory=$false)] [ValidateNotNullOrEmpty()] [String] $Name = 'transition-validation',
        [Parameter(Mandatory=$false)] [Int] $Order = 0,
        [Parameter(Mandatory=$false)]
        [ValidateSet('', 'Ryzen5000', 'Ryzen7000', 'Ryzen8000', 'Ryzen9000')]
        [String] $RyzenGeneration = '',
        [Parameter(Mandatory=$false)] [Int] $ExpectedCoreCount = 0,
        [Parameter(Mandatory=$false)] $Sections = $null,
        [Parameter(Mandatory=$false)] [Switch] $AllowPositiveCurveOptimizer
    )

    if ($ExpectedCoreCount -lt 0) {
        throw('ExpectedCoreCount cannot be negative.')
    }

    $candidateValues = @(Resolve-CoreCyclerCandidateCurveOptimizerMap -CandidateMap $CandidateMap)

    if ($candidateValues.Count -lt 1) {
        throw('Candidate Curve Optimizer map cannot be empty.')
    }

    if ($ExpectedCoreCount -gt 0 -and $candidateValues.Count -ne $ExpectedCoreCount) {
        throw('Candidate Curve Optimizer map contains ' + $candidateValues.Count + ' values, expected ' + $ExpectedCoreCount + '.')
    }

    if (!$AllowPositiveCurveOptimizer.IsPresent -and (Test-CoreCyclerPositiveCurveOptimizerValue $candidateValues)) {
        throw('Positive Curve Optimizer value found in candidate daily map. Use -AllowPositiveCurveOptimizer only for explicit positive CO opt-in.')
    }

    $phaseSections = [ordered]@{}

    foreach ($entry in (Get-CoreCyclerMapEntries $Sections)) {
        $phaseSections[$entry.Key] = $entry.Value
    }

    $general = Get-CoreCyclerMapValue $phaseSections 'General' ([ordered]@{})
    $phaseSections['General'] = Merge-CoreCyclerSection $general ([ordered]@{
        suspendPeriodically = 1
        coreTestOrder       = 'CorePairs'
    })

    $automaticTestMode = Get-CoreCyclerMapValue $phaseSections 'AutomaticTestMode' ([ordered]@{})
    $phaseSections['AutomaticTestMode'] = Merge-CoreCyclerSection $automaticTestMode ([ordered]@{
        enableAutomaticAdjustment       = 0
        startValues                     = @($candidateValues)
        maxValue                        = 0
        setVoltageOnlyForTestedCore     = 0
        voltageValueForNotTestedCores   = 0
        enableResumeAfterUnexpectedExit = 0
    })

    if ([String]::IsNullOrWhiteSpace($RyzenGeneration)) {
        $phase = New-CoreCyclerPhase -Name $Name -Type TransitionValidation -Order $Order -Sections $phaseSections
    }
    else {
        $phase = New-CoreCyclerPhase -Name $Name -Type TransitionValidation -Order $Order -RyzenGeneration $RyzenGeneration -Sections $phaseSections
    }

    $phase['CandidateMap'] = @($candidateValues)
    $phase['MapApplication'] = 'Candidate map must already be active before transition validation; with enableAutomaticAdjustment = 0, CoreCycler will not apply startValues.'

    return $phase
}

Export-ModuleMember -Function @(
    'Get-CoreCyclerRyzenGenerationProfile'
    'New-CoreCyclerPhase'
    'New-CoreCyclerCombinedMapValidationPhase'
    'New-CoreCyclerTransitionValidationPhase'
    'ConvertTo-CoreCyclerIni'
    'Export-CoreCyclerPhaseConfig'
    'Test-CoreCyclerPhaseSequence'
    'ConvertFrom-CoreCyclerSummaryText'
    'Get-CoreCyclerCandidateCurveOptimizerMap'
)
