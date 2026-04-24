Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$modulePath = Join-Path $PSScriptRoot '..\helpers\CoreCyclerPhaseConfig.psm1'
Import-Module $modulePath -Force

$Script:TestCount = 0

function Assert-True {
    param(
        [Parameter(Mandatory=$true)] [Bool] $Condition,
        [Parameter(Mandatory=$false)] [String] $Message = 'Expected condition to be true.'
    )

    if (!$Condition) {
        throw($Message)
    }
}

function Assert-Equal {
    param(
        [Parameter(Mandatory=$false)] $Actual,
        [Parameter(Mandatory=$false)] $Expected,
        [Parameter(Mandatory=$false)] [String] $Message = 'Values were not equal.'
    )

    if ($Actual -ne $Expected) {
        throw($Message + ' Expected "' + $Expected + '", got "' + $Actual + '".')
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

function It {
    param(
        [Parameter(Mandatory=$true)] [String] $Name,
        [Parameter(Mandatory=$true)] [ScriptBlock] $Body
    )

    & $Body
    $Script:TestCount++
    Write-Host ('PASS: ' + $Name)
}

function Get-ParsedSummaryFixture {
    param(
        [Parameter(Mandatory=$true)] [String] $Name
    )

    $fixture = Get-Content -LiteralPath (Join-Path $PSScriptRoot ('fixtures\' + $Name)) -Raw
    return ConvertFrom-CoreCyclerSummaryText -Text $fixture
}

It 'emits candidate daily maps by applying margin toward zero' {
    $summary = Get-ParsedSummaryFixture 'final-summary-adjusted-clean.log'
    $recommendation = Get-CoreCyclerCandidateCurveOptimizerMap -Summary $summary -SafetyMargin 2

    Assert-ArrayEqual -Actual $recommendation.EdgeMap -Expected @(-20, -17, -15, -28)
    Assert-ArrayEqual -Actual $recommendation.CandidateMap -Expected @(-18, -15, -13, -26)
    Assert-Equal $recommendation.SafetyMargin 2
    Assert-ArrayEqual -Actual $recommendation.InstabilityReasons -Expected @()
}

It 'never makes recommended CO values more negative than the edge map' {
    $summary = Get-ParsedSummaryFixture 'final-summary-adjusted-clean.log'
    $recommendation = Get-CoreCyclerCandidateCurveOptimizerMap -Summary $summary -SafetyMargin 3

    for ($i = 0; $i -lt $recommendation.EdgeMap.Count; $i++) {
        Assert-True ($recommendation.CandidateMap[$i] -ge $recommendation.EdgeMap[$i]) ('Core ' + $i + ' became more negative.')
    }
}

It 'clamps candidate maps at zero without positive CO opt-in' {
    $summary = Get-ParsedSummaryFixture 'final-summary-clean.log'
    $recommendation = Get-CoreCyclerCandidateCurveOptimizerMap -Summary $summary -SafetyMargin 20

    Assert-ArrayEqual -Actual $recommendation.EdgeMap -Expected @(-10, -12, -8, 0)
    Assert-ArrayEqual -Actual $recommendation.CandidateMap -Expected @(0, 0, 0, 0)
    Assert-ArrayEqual -Actual $recommendation.ClampedCores -Expected @(0, 1, 2, 3)
    Assert-True (!$recommendation.AllowPositiveCurveOptimizer)
}

It 'rejects positive maximum values without explicit positive CO opt-in' {
    $summary = Get-ParsedSummaryFixture 'final-summary-clean.log'

    Assert-Throws { Get-CoreCyclerCandidateCurveOptimizerMap -Summary $summary -SafetyMargin 20 -MaximumValue 2 } 'Positive Curve Optimizer output requires'
}

It 'allows positive candidate maps only with explicit opt-in' {
    $summary = Get-ParsedSummaryFixture 'final-summary-clean.log'
    $recommendation = Get-CoreCyclerCandidateCurveOptimizerMap -Summary $summary -SafetyMargin 20 -MaximumValue 2 -AllowPositiveCurveOptimizer

    Assert-ArrayEqual -Actual $recommendation.CandidateMap -Expected @(2, 2, 2, 2)
    Assert-True $recommendation.AllowPositiveCurveOptimizer
}

It 'rejects negative safety margins' {
    $summary = Get-ParsedSummaryFixture 'final-summary-clean.log'

    Assert-Throws { Get-CoreCyclerCandidateCurveOptimizerMap -Summary $summary -SafetyMargin -1 } 'Cannot validate argument'
}

It 'rejects unstable summaries by default' {
    $summary = Get-ParsedSummaryFixture 'final-summary-with-errors.log'

    Assert-Throws { Get-CoreCyclerCandidateCurveOptimizerMap -Summary $summary -SafetyMargin 2 } 'Cannot recommend a candidate daily Curve Optimizer map from an unstable summary'
}

It 'rejects each instability signal independently' {
    $baseCurveOptimizer = [PSCustomObject]@{
        Found       = $true
        FinalValues = @(-20, -17, -15, -28)
    }

    $summaryWithCoreErrors = [PSCustomObject]@{
        CoresWithErrors = @(1)
        ErrorDetails    = @()
        Whea            = [PSCustomObject]@{ TotalCount = 0; Cores = @() }
        CurveOptimizer  = $baseCurveOptimizer
    }

    $summaryWithErrorDetails = [PSCustomObject]@{
        CoresWithErrors = @()
        ErrorDetails    = @([PSCustomObject]@{ ErrorType = 'CALCULATIONERROR' })
        Whea            = [PSCustomObject]@{ TotalCount = 0; Cores = @() }
        CurveOptimizer  = $baseCurveOptimizer
    }

    $summaryWithWhea = [PSCustomObject]@{
        CoresWithErrors = @()
        ErrorDetails    = @()
        Whea            = [PSCustomObject]@{ TotalCount = 1; Cores = @([PSCustomObject]@{ Core = 2; Count = 1 }) }
        CurveOptimizer  = $baseCurveOptimizer
    }

    Assert-Throws { Get-CoreCyclerCandidateCurveOptimizerMap -Summary $summaryWithCoreErrors } 'cores with errors'
    Assert-Throws { Get-CoreCyclerCandidateCurveOptimizerMap -Summary $summaryWithErrorDetails } 'error details'
    Assert-Throws { Get-CoreCyclerCandidateCurveOptimizerMap -Summary $summaryWithWhea } 'WHEA count'
}

It 'allows unstable summaries only with explicit diagnostic opt-in' {
    $summary = Get-ParsedSummaryFixture 'final-summary-with-errors.log'
    $recommendation = Get-CoreCyclerCandidateCurveOptimizerMap -Summary $summary -SafetyMargin 2 -AllowUnstableSummary

    Assert-ArrayEqual -Actual $recommendation.CandidateMap -Expected @(-18, -15, -13, -26)
    Assert-True $recommendation.AllowUnstableSummary
    Assert-True ($recommendation.InstabilityReasons.Count -gt 0)
}

Write-Host ('safety-margin.Tests.ps1: ' + $Script:TestCount + ' tests passed.')
