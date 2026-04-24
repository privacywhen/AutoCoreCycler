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

function It {
    param(
        [Parameter(Mandatory=$true)] [String] $Name,
        [Parameter(Mandatory=$true)] [ScriptBlock] $Body
    )

    & $Body
    $Script:TestCount++
    Write-Host ('PASS: ' + $Name)
}

It 'parses final CO maps from adjusted final summaries' {
    $fixture = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'fixtures\final-summary-adjusted-clean.log') -Raw
    $summary = ConvertFrom-CoreCyclerSummaryText -Text $fixture

    Assert-True $summary.CurveOptimizer.Found
    Assert-True $summary.CurveOptimizer.Adjusted
    Assert-ArrayEqual -Actual $summary.CurveOptimizer.Cores -Expected @(0, 1, 2, 3)
    Assert-ArrayEqual -Actual $summary.CurveOptimizer.StartingValues -Expected @(-20, -20, -15, -30)
    Assert-ArrayEqual -Actual $summary.CurveOptimizer.CurrentValues -Expected @(-20, -17, -15, -28)
    Assert-ArrayEqual -Actual $summary.CurveOptimizer.FinalValues -Expected @(-20, -17, -15, -28)
}

It 'parses WHEA counts from final summaries' {
    $fixture = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'fixtures\final-summary-with-errors.log') -Raw
    $summary = ConvertFrom-CoreCyclerSummaryText -Text $fixture

    Assert-Equal $summary.Whea.TotalCount 3
    Assert-Equal $summary.Whea.Cores.Count 2
    Assert-Equal $summary.Whea.Cores[0].Core 1
    Assert-Equal $summary.Whea.Cores[0].Count 1
    Assert-Equal $summary.Whea.Cores[1].Core 3
    Assert-Equal $summary.Whea.Cores[1].Count 2
}

It 'parses per-core error lists and details from final summaries' {
    $fixture = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'fixtures\final-summary-with-errors.log') -Raw
    $summary = ConvertFrom-CoreCyclerSummaryText -Text $fixture

    Assert-ArrayEqual -Actual $summary.CoresWithErrors -Expected @(1, 3)
    Assert-Equal $summary.ErrorDetails.Count 2
    Assert-Equal $summary.ErrorDetails[0].Core 1
    Assert-Equal $summary.ErrorDetails[0].Cpu '2'
    Assert-Equal $summary.ErrorDetails[0].ErrorType 'CALCULATIONERROR'
    Assert-Equal $summary.ErrorDetails[0].StressTestError 'FATAL ERROR: Rounding was 0.5, expected less than 0.4'
    Assert-Equal $summary.ErrorDetails[1].Core 3
    Assert-Equal $summary.ErrorDetails[1].ErrorType 'WHEAERROR'
    Assert-Equal $summary.ErrorDetails[1].ErrorMessage 'Processor APIC ID: 6'
}

It 'parses clean final summaries without errors or WHEA' {
    $fixture = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'fixtures\final-summary-clean.log') -Raw
    $summary = ConvertFrom-CoreCyclerSummaryText -Text $fixture

    Assert-ArrayEqual -Actual $summary.CoresWithErrors -Expected @()
    Assert-Equal $summary.ErrorDetails.Count 0
    Assert-Equal $summary.Whea.TotalCount 0
    Assert-Equal $summary.Whea.Cores.Count 0
    Assert-True $summary.CurveOptimizer.Found
    Assert-True (!$summary.CurveOptimizer.Adjusted)
    Assert-ArrayEqual -Actual $summary.CurveOptimizer.Cores -Expected @(0, 1, 2, 3)
    Assert-ArrayEqual -Actual $summary.CurveOptimizer.FinalValues -Expected @(-10, -12, -8, 0)
}

Write-Host ('summary-parser.Tests.ps1: ' + $Script:TestCount + ' tests passed.')
