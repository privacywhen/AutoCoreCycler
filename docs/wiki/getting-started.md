# Getting Started

## What this repository runs

AutoCoreCycler is a Windows PowerShell tool for per-physical-core stress testing. It can use Prime95, y-cruncher, AIDA64, or Linpack. Automatic Test Mode can apply Ryzen Curve Optimizer values or Intel voltage offsets, so it has real hardware and Windows-system consequences.

## Prerequisites

- Windows with Windows PowerShell.
- A supported stress executable in its expected `test_programs/` location. AIDA64 is not distributed and must be Portable Engineer when used.
- A working Windows Performance Process Counter (`PerfProc`) where required.
- Ryzen ATM: administrator privileges, PawnIO installed, and the bundled `tools/ryzen-smu-cli` path available.
- Automatic recovery: a Windows logon after reboot; unattended recovery additionally depends on Windows Auto Logon.

## Normal launch

Run from Windows Explorer:

```text
Run CoreCycler.bat
```

On first use CoreCycler creates a configuration file with setting descriptions. Review it before running a workload; [`configs/default.config.ini`](../../configs/default.config.ini) and supplied profiles are the starting references.

## Existing ATM and discovery status

[`configs/Ryzen.AutomaticTestMode.Start.ini`](../../configs/Ryzen.AutomaticTestMode.Start.ini) demonstrates existing Ryzen ATM. Existing ATM adjusts from start values toward `maxValue` after errors and uses a configured number of consecutive passes for legacy `confirmed` state. That is not the planned descending discovery workflow.

The planned next phase is **Phase 1: pure discovery semantics**. The untracked discovery module and Pester tests do not connect to production launch, CO writes, workloads, or resume. Do not treat them as an executable discovery mode.

## Safety

- Stress workloads can cause high temperature, instability, freezes, crashes, or data/Windows damage.
- CO/PBO use is at the operator's risk; upstream documentation recommends a restore point before aggressive testing.
- Do not run stress loads, apply CO values, change BIOS/PBO settings, or add privilege persistence merely to test software changes. `AGENTS.md` requires specific authorization.
- Stop CoreCycler with `Ctrl+C`; closing its window can leave its resume task behind.

## Runtime locations

| Location | Purpose |
|---|---|
| `configs/` | Default and workload/ATM profiles. |
| `logs/` | Runtime logs and append-only result files, created at runtime. |
| `.automode` / `.automode-bak` | Runtime recovery state at repository root. |
| `helpers/` | Event Log and automatic-resume scripts. |
| `tools/` | Topology and CO/voltage tools. |
| `test_programs/` | Bundled/expected stress-program directories. |
