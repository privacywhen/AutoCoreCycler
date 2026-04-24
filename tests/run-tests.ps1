Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$testFiles = @(Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.Tests.ps1' | Sort-Object -Property Name)

if ($testFiles.Count -eq 0) {
    Write-Host 'No tests found.'
    exit 0
}

$failedTests = @()

foreach ($testFile in $testFiles) {
    Write-Host ('Running ' + $testFile.Name)

    try {
        & $testFile.FullName
    }
    catch {
        $failedTests += $testFile.Name
        Write-Host ('FAIL: ' + $testFile.Name)
        Write-Host $_.Exception.Message
    }
}

if ($failedTests.Count -gt 0) {
    Write-Host ''
    Write-Host ('Failed test files: ' + ($failedTests -Join ', '))
    exit 1
}

Write-Host ''
Write-Host ('All test files passed: ' + $testFiles.Count)
