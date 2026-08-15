$repoPath = Split-Path -Parent $PSScriptRoot
Import-Module (Join-Path $repoPath 'helpers\discovery-child-launch.psm1') -Force

Describe 'Discovery child execution boundary' {
    BeforeEach {
        $script:childScriptPath = Join-Path $TestDrive 'synthetic-child.ps1'
        $script:stageConfigPath = Join-Path $TestDrive 'stage-kagari.ini'
        $script:stageLogPath = Join-Path $TestDrive 'stage-kagari.log'
        [System.IO.File]::WriteAllText($childScriptPath, "param([String]`$ConfigPath)`r`nStart-Sleep -Milliseconds 1500")
        [System.IO.File]::WriteAllText($stageConfigPath, '[General]' + [Environment]::NewLine + 'stressTestProgram = ycruncher')
        $script:plan = New-DiscoveryStageChildLaunchPlan -ChildScriptPath $childScriptPath -StageConfigPath $stageConfigPath -CoreNumber 2 -Candidate -18 -CandidateAttemptId 'candidate-core2--18-a' -StageAttemptId 'stage-kagari-a' -WorkloadId 'kagari' -LogPath $stageLogPath
        $script:launchedProcessId = $null
    }

    It 'launches a ready synthetic child and binds its observed identity to a stage context' {
        try {
            $launch = Start-DiscoveryStageChildFromPlan -Plan $plan
            $script:launchedProcessId = $launch.Context.childProcessId

            $launch.Launched | Should Be $true
            $launch.Reason | Should Be 'launched'
            $launch.Context.childProcessId | Should BeGreaterThan 0
            $launch.Context.startedAt.Kind | Should Be ([DateTimeKind]::Utc)
            $launch.Context.candidateAttemptId | Should Be 'candidate-core2--18-a'
            $launch.Context.stageAttemptId | Should Be 'stage-kagari-a'
            $launch.Context.configFingerprint | Should Be $plan.Identity.configFingerprint
        }
        finally {
            if ($null -ne $launchedProcessId) {
                Wait-Process -Id $launchedProcessId -Timeout 10 -ErrorAction SilentlyContinue
            }
        }
    }

    It 'reports no launch when the child process cannot start' {
        $module = Get-Module | Where-Object { $_.Path -eq (Join-Path $repoPath 'helpers\discovery-child-launch.psm1') }
        Mock -CommandName Start-Process -ModuleName $module.Name -MockWith { throw 'synthetic launch failure' }

        $launch = Start-DiscoveryStageChildFromPlan -Plan $plan

        $launch.Launched | Should Be $false
        $launch.Reason | Should Be 'child_launch_failed'
        $launch.ChildProcessId | Should Be $null
        $launch.Context | Should Be $null
    }

    It 'reports an unavailable child identity after a confirmed launch' {
        $module = Get-Module | Where-Object { $_.Path -eq (Join-Path $repoPath 'helpers\discovery-child-launch.psm1') }
        $global:syntheticStartProcess = New-Object PSObject
        Add-Member -InputObject $global:syntheticStartProcess -MemberType ScriptProperty -Name Id -Value { throw 'synthetic process identity failure' }
        Mock -CommandName Start-Process -ModuleName $module.Name -MockWith { return $global:syntheticStartProcess }

        $launch = Start-DiscoveryStageChildFromPlan -Plan $plan

        $launch.Launched | Should Be $true
        $launch.Reason | Should Be 'child_process_identity_unavailable'
        $launch.ChildProcessId | Should Be $null
        $launch.Context | Should Be $null
    }

    It 'retains a started PID when start-time observation fails after launch' {
        $module = Get-Module | Where-Object { $_.Path -eq (Join-Path $repoPath 'helpers\discovery-child-launch.psm1') }
        $global:syntheticStartProcess = New-Object PSObject
        Add-Member -InputObject $global:syntheticStartProcess -MemberType NoteProperty -Name Id -Value 4242
        Add-Member -InputObject $global:syntheticStartProcess -MemberType ScriptProperty -Name StartTime -Value { throw 'synthetic start-time observation failure' }
        Mock -CommandName Start-Process -ModuleName $module.Name -MockWith { return $global:syntheticStartProcess }

        $launch = Start-DiscoveryStageChildFromPlan -Plan $plan

        $launch.Launched | Should Be $true
        $launch.Reason | Should Be 'child_start_time_unavailable'
        $launch.ChildProcessId | Should Be 4242
        $launch.Context | Should Be $null
    }

    It 'does not launch a synthetic child when config drift invalidates readiness' {
        $markerPath = Join-Path $TestDrive 'synthetic-child-ran.marker'
        [System.IO.File]::WriteAllText($childScriptPath, "param([String]`$ConfigPath)`r`n[System.IO.File]::WriteAllText('$markerPath', 'executed')")
        [System.IO.File]::AppendAllText($stageConfigPath, [Environment]::NewLine + 'runtimePerCore = 3m')

        $launch = Start-DiscoveryStageChildFromPlan -Plan $plan
        Start-Sleep -Milliseconds 300

        $launch.Launched | Should Be $false
        $launch.Reason | Should Be 'config_fingerprint_mismatch'
        $launch.ChildProcessId | Should Be $null
        $launch.Context | Should Be $null
        (Test-Path -LiteralPath $markerPath) | Should Be $false
    }
}
