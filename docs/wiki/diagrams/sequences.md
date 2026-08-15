# Sequence Diagrams

## Existing Automatic Test Mode startup and recovery

```mermaid
sequenceDiagram
    participant User
    participant Launcher as Run CoreCycler.bat
    participant Main as script-corecycler.ps1
    participant State as .automode / .automode-bak
    participant Task as Task Scheduler
    participant Helper as automode-startup-script.ps1

    User->>Launcher: Start test
    Launcher->>Main: Launch PowerShell script
    Main->>Main: Import settings and initialize ATM
    Main->>Task: Register resume task when enabled
    Main->>State: Save active core, values, states, remaining order
    Note over Main: Unexpected exit / reboot
    Task->>Helper: Run at logon
    Helper->>State: Read current state, then backup if needed
    Helper->>Launcher: Restart with saved core number
    Launcher->>Main: Resume run
    Main->>State: Restore state and merge permanent results
```

This reflects the current legacy ATM implementation.

## Optional discovery snapshot persistence

```mermaid
sequenceDiagram
    participant Main as script-corecycler.ps1
    participant Snapshot as discovery-state.psm1
    participant File as .automode JSON
    participant Backup as .automode-bak

    Main->>File: Read existing automatic-mode document
    Main->>Snapshot: Restore-DiscoveryStateSnapshot when discoveryStates exists
    Snapshot-->>Main: All states or fail-closed rejection
    Main->>File: Save legacy fields unchanged when discovery is unused
    Main->>Snapshot: ConvertTo-DiscoveryStateSnapshot when discovery state exists
    Snapshot-->>Main: schemaVersion 2 snapshot
    Main->>File: Write validated temporary generation
    File->>Backup: Rotate previous valid generation
```

The discovery field is optional and isolated from legacy ATM state. Malformed, stale, torn, missing-core, or unexpected-core discovery snapshots are rejected without returning a partial state.

## Phase 3 child-launch seam

```mermaid
sequenceDiagram
    participant Caller as Synthetic caller / future coordinator
    participant Plan as discovery-child-launch.psm1
    participant Ready as Readiness validator
    participant Child as powershell.exe child
    participant Binder as Observation binder
    participant Context as Stage context

    Caller->>Plan: Build deterministic plan
    Caller->>Ready: Revalidate script, config fingerprint, root-config rule, fresh log
    alt Not ready
        Ready-->>Caller: Launched=false, reason, no PID/context
    else Ready
        Caller->>Plan: Start-DiscoveryStageChildFromPlan
        Plan->>Child: Start-Process exact tokenized invocation
        Child-->>Plan: Process object
        Plan->>Plan: Validate positive exact PID and capture UTC StartTime
        Plan->>Binder: Bind PID + UTC time + plan identity
        Binder->>Context: Rebuild and revalidate fingerprint-bound context
        alt Observation accepted
            Context-->>Caller: Launched=true, context
        else Observation unavailable or stale
            Context-->>Caller: Launched=true, acquired PID, no context
        end
    end
```

This is an isolated execution seam, not a production discovery call path. The current test uses only a harmless temporary child script; no CoreCycler workload, parser, CO action, scheduler/resume action, UAC flow, or hardware operation is invoked.

## Pure ordered suite reduction

```mermaid
sequenceDiagram
    participant Coordinator as Synthetic suite reducer
    participant Evidence as Stage evidence contract
    participant State as Discovery state reducer

    Coordinator->>Evidence: Validate current stage identity/result
    Evidence-->>Coordinator: Accepted or stale/mismatched rejection
    Coordinator->>Coordinator: Require exact workload order
    Coordinator->>Coordinator: Require childExited=true and cleanupVerified=true
    alt Non-final PASS
        Coordinator->>Coordinator: Advance one workload index
    else Final PASS
        Coordinator->>State: Submit complete-suite OBSERVED_PASS evidence
        State-->>Coordinator: Candidate advances exactly -1 or resolves at minimum
    else ATTRIBUTED_FAIL / AMBIGUOUS_FAIL / INFRASTRUCTURE_INVALID
        Coordinator->>State: Submit narrow classification
        State-->>Coordinator: Fail, quarantine, or fresh-identity retry without false boundary
    end
```

The reducer is synthetic and pure. Runtime stage parsing and coordinator wiring remain future work.
