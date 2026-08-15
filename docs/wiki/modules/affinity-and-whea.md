# Module: Affinity and WHEA

## Purpose

This subsystem maps logical CPUs to physical cores, restricts stress-test threads to the selected core, and checks WHEA events. It is central to per-core testing and future discovery attribution.

## Key source locations

- [`Set-StressTestProgramAffinities`](../../../script-corecycler.ps1#L12025) calculates processor-group affinity for stress threads.
- [`Get-LastWheaError`](../../../script-corecycler.ps1#L12703) reads WHEA Logger events.
- [`Compare-WheaErrorEntries`](../../../script-corecycler.ps1#L12735) filters for events newer than the active core test.
- [`Convert-WheaMessageToCoreId`](../../../script-corecycler.ps1#L12850) maps WHEA APIC ID to a physical core.
- [`Get-ProcessorCoresInformation`](../../../script-corecycler.ps1#L12910) builds mappings through `tools/APICID.exe`.

## Behavior

APICID produces logical-CPU, physical-core, APIC-ID, and SMT records used to build lookup tables such as `apicIdToCore` and `coreToCpus`. Affinity supports processor groups and systems beyond 64 logical processors.

For discovery, WHEA can be attributed only when a usable APIC mapping identifies the active core. Missing or mismatched APIC mappings remain ambiguous. Affinity proves scheduling intent, not effective CO application; discovery needs a separate verification gate.
