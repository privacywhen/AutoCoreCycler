# Module: Main orchestrator

## Purpose

[`script-corecycler.ps1`](../../../script-corecycler.ps1) is the application implementation. This large PowerShell script centralizes configuration, logging, dependency checks, CPU/core discovery, stress-program control, affinity, automatic adjustment, persistence, WHEA observation, Event Log integration, and cleanup.

## Responsibilities

- Import and validate INI settings.
- Determine processor, physical-core, logical-CPU, APIC, SMT, and processor-group relationships.
- Initialize/control the selected stress program and assign affinity.
- Initialize Automatic Test Mode and coordinate state, results, and recovery.

## Important functions

| Function | Role |
|---|---|
| `Import-Settings` / `Get-Settings` | Parse and validate configuration. |
| `Initialize-AutomaticTestMode` | Prepare existing ATM values, state, persistence, and resume. |
| `Initialize-StressTestProgram` / `Start-StressTestProgram` / `Close-StressTestProgram` | Generic adapter lifecycle. |
| `Set-StressTestProgramAffinities` | Assign stress threads to selected physical-core CPUs. |
| `Get-ProcessorCoresInformation` | Build CPU/core/APIC lookup tables using APICID. |

## Dependencies and gotchas

The script uses Windows PowerShell, Event Log, Task Scheduler, bundled platform tools, and selected stress executables. Its legacy ATM direction and evidence semantics are not descending discovery. The Phase 1 helper is intentionally outside this execution path.
