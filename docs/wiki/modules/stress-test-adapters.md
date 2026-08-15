# Module: Stress-test adapters

## Purpose

The main script wraps multiple stress programs behind a shared lifecycle so scheduling and ATM avoid duplicating high-level control.

| Program | Initialize | Start | Close |
|---|---|---|---|
| Prime95 | `Initialize-Prime95` | `Start-Prime95` | `Close-Prime95` |
| y-cruncher | `Initialize-yCruncher` | `Start-yCruncher` | `Close-yCruncher` |
| AIDA64 | `Initialize-Aida64` | `Start-Aida64` | `Close-Aida64` |
| Linpack | `Initialize-Linpack` | `Start-Linpack` | `Close-Linpack` |

Generic entrypoints are `Initialize-StressTestProgram`, `Start-StressTestProgram`, and `Close-StressTestProgram` in [`script-corecycler.ps1`](../../../script-corecycler.ps1). `Get-NewLogfileEntries` incrementally reads stress logs and resets its positions if a log is recreated or truncated.

## Proposed discovery suite

`DESIGN.md` defines y-cruncher Kagari (BKT, BBP, SFTv4, SNT, SVT, FFTv4, N63, VT3; two threads), Prime95 SSE Huge FFT (8960K–32768K; one thread), Prime95 AVX2 720K/768K, and Prime95 AVX2 1344K (the AVX2 stages one thread and three minutes/core).

A candidate passes only after every stage passes after application verification. This coordination is not in production source; Phase 3 must select a minimal coordinator from actual lifecycle evidence.
