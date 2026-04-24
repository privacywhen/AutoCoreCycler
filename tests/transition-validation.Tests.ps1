Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot '..\helpers\CoreCyclerPhaseConfig.psm1'
Import-Module $modulePath -Force

$Script:TestCount = 0

function Assert-MatchText {
    param(
        [Parameter(Mandatory=$true)] [String] $Text,
        [Parameter(Mandatory=$true)] [String] $Pattern
    )

    if ($Text -NotMatch $Pattern) {
        throw('Expected text to match pattern: ' + $Pattern)
    }
}

function Assert-ArrayEqual {
    param(
        [Parameter(Mandatory=$true)][AllowEmptyCollection()] [Object[]] $Actual,
        [Parameter(Mandatory=$true)][AllowEmptyCollection()] [Object[]] $Expected,
        [Parameter(Mandatory=$false)] [String] $Message = 'Arrays were not equal.'
    )

    if ($Actual.Count -ne $Expected.Count) {
        throw($Message + ' Expected count ' + $Expected.Count + ', got ' + $Actual.Count + '.')
    }

    for ($i = 0; $i -lt $Expected.Count; $i++) {
        if ($Actual[$i] -ne $Expected[$i]) {
            throw($Message + ' Difference at index ' + $i + ': expected "' + $Expected[$i] + '", got "' + $Actual[$i] + '".')
        }
    }
}

function Assert-Throws {
    param(
        [Parameter(Mandatory=$true)] [ScriptBlock] $ScriptBlock,
        [Parameter(Mandatory=$false)] [String] $MessagePattern
    )

    $threw = $false

    try {
        & $ScriptBlock | Out-Null
    }
    catch {
        $threw = $true

        if ($MessagePattern -and $_.Exception.Message -NotMatch $MessagePattern) {
            throw('Expected exception matching "' + $MessagePattern + '", got: ' + $_.Exception.Message)
        }
    }

    if (!$threw) {
        throw('Expected script block to throw.')
    }
}

function Assert-SameNormalizedText {
    param(
        [Parameter(Mandatory=$true)] [String] $Actual,
        [Parameter(Mandatory=$true)] [String] $Expected
    )

    $normalizedActual = $Actual.Replace("`r`n", "`n").TrimEnd()
    $normalizedExpected = $Expected.Replace("`r`n", "`n").TrimEnd()

    if ($normalizedActual -ne $normalizedExpected) {
        throw('Generated text did not match the expected fixture.')
    }
}

function It {
    param(
        [Parameter(Mandatory=$true)] [String] $Name,
        [Parameter(Mandatory=$true)] [ScriptBlock] $Body
    )

    & $Body
    $Script:TestCount++
    Write-Host ('PASS: ' + $Name)
}

function Get-CandidateRecommendationFixture {
    $summaryText = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'fixtures\final-summary-adjusted-clean.log') -Raw
    $summary = ConvertFrom-CoreCyclerSummaryText -Text $summaryText
    return Get-CoreCyclerCandidateCurveOptimizerMap -Summary $summary -SafetyMargin 2
}

It 'creates CorePairs transition validation phases from candidate recommendations' {
    $recommendation = Get-CandidateRecommendationFixture
    $phase = New-CoreCyclerTransitionValidationPhase -Name 'transition-validation' -CandidateMap $recommendation -RyzenGeneration Ryzen7000 -ExpectedCoreCount 4
    $ini = ConvertTo-CoreCyclerIni -Phase $phase

    Assert-ArrayEqual -Actual $phase.CandidateMap -Expected @(-18, -15, -13, -26)
    Assert-MatchText $ini '(?m)^# PhaseType = TransitionValidation\r?$'
    Assert-MatchText $ini '(?m)^# CandidateMap = -18, -15, -13, -26\r?$'
    Assert-MatchText $ini '(?m)^# MapApplication = Candidate map must already be active before transition validation; with enableAutomaticAdjustment = 0, CoreCycler will not apply startValues\.\r?$'
    Assert-MatchText $ini '(?m)^coreTestOrder = CorePairs\r?$'
    Assert-MatchText $ini '(?m)^suspendPeriodically = 1\r?$'
    Assert-MatchText $ini '(?m)^startValues = -18, -15, -13, -26\r?$'
    Assert-MatchText $ini '(?m)^enableAutomaticAdjustment = 0\r?$'
    Assert-MatchText $ini '(?m)^setVoltageOnlyForTestedCore = 0\r?$'
    Assert-MatchText $ini '(?m)^voltageValueForNotTestedCores = 0\r?$'
    Assert-MatchText $ini '(?m)^enableResumeAfterUnexpectedExit = 0\r?$'

    if ($ini -Match '(?m)^enableAutomaticAdjustment = 1\r?$') {
        throw('Transition validation must not enable automatic adjustment by default.')
    }

    if ($ini -Match '(?m)^setVoltageOnlyForTestedCore = 1\r?$') {
        throw('Transition validation must keep all candidate CO values active together.')
    }
}

It 'matches the transition validation fixture' {
    $recommendation = Get-CandidateRecommendationFixture
    $phase = New-CoreCyclerTransitionValidationPhase -Name 'transition-validation' -CandidateMap $recommendation -RyzenGeneration Ryzen7000 -ExpectedCoreCount 4
    $ini = ConvertTo-CoreCyclerIni -Phase $phase
    $fixture = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'fixtures\transition-validation.ini') -Raw

    Assert-SameNormalizedText -Actual $ini -Expected $fixture
}

It 'forces transition guardrails even when overrides try to disable them' {
    $phase = New-CoreCyclerTransitionValidationPhase -Name 'safe-transition' -CandidateMap @(-5, -4, -3, 0) -Sections @{
        General = @{
            runtimePerCore = '15m'
            coreTestOrder = 'Default'
            suspendPeriodically = 0
        }
        AutomaticTestMode = @{
            enableAutomaticAdjustment = 1
            maxValue = 5
            setVoltageOnlyForTestedCore = 1
            enableResumeAfterUnexpectedExit = 1
        }
    }

    $ini = ConvertTo-CoreCyclerIni -Phase $phase

    Assert-MatchText $ini '(?m)^runtimePerCore = 15m\r?$'
    Assert-MatchText $ini '(?m)^coreTestOrder = CorePairs\r?$'
    Assert-MatchText $ini '(?m)^suspendPeriodically = 1\r?$'
    Assert-MatchText $ini '(?m)^enableAutomaticAdjustment = 0\r?$'
    Assert-MatchText $ini '(?m)^maxValue = 0\r?$'
    Assert-MatchText $ini '(?m)^setVoltageOnlyForTestedCore = 0\r?$'
    Assert-MatchText $ini '(?m)^enableResumeAfterUnexpectedExit = 0\r?$'
}

It 'rejects positive candidate maps by default' {
    Assert-Throws { New-CoreCyclerTransitionValidationPhase -CandidateMap @(-5, 1, 0, -2) } 'Positive Curve Optimizer value found'
}

It 'requires positive CO opt-in at generation and INI conversion time' {
    $phase = New-CoreCyclerTransitionValidationPhase -Name 'explicit-positive-transition' -CandidateMap @(-5, 1, 0, -2) -AllowPositiveCurveOptimizer

    Assert-Throws { ConvertTo-CoreCyclerIni -Phase $phase } 'Positive Curve Optimizer'

    $ini = ConvertTo-CoreCyclerIni -Phase $phase -AllowPositiveCurveOptimizer
    Assert-MatchText $ini '(?m)^# WARNING: Positive Curve Optimizer values were explicitly allowed'
    Assert-MatchText $ini '(?m)^startValues = -5, 1, 0, -2\r?$'
}

It 'rejects candidate maps that do not match an expected core count' {
    Assert-Throws { New-CoreCyclerTransitionValidationPhase -CandidateMap @(-5, -4, -3) -ExpectedCoreCount 4 } 'expected 4'
}

Write-Host ('transition-validation.Tests.ps1: ' + $Script:TestCount + ' tests passed.')
