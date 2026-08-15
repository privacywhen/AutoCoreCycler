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

This reflects the current ATM implementation.

## Proposed discovery candidate evidence flow

```mermaid
sequenceDiagram
    participant Scheduler as Discovery scheduler
    participant State as Durable discovery state
    participant CO as Existing CO application
    participant Verify as Effective-map verification
    participant Stage as Workload stage
    participant Evidence as Evidence classifier

    Scheduler->>State: Persist candidate attempt identity
    Scheduler->>CO: Apply active-core candidate
    CO-->>Verify: Applied map
    Verify->>State: Persist APPLIED_VERIFIED
    loop Each required stage
        Scheduler->>Stage: Start with fresh stage-attempt ID
        Stage-->>Evidence: Workload/log/WHEA evidence
        Evidence->>State: Persist stage result
    end
    alt Verified complete suite passes
        Evidence->>State: Record pass; advance exactly -1
    else Positive attributable failure
        Evidence->>State: Resolve to previous pass
    else Ambiguous disruption
        Evidence->>State: Quarantine; no boundary
    else Infrastructure invalidation
        Evidence->>State: Preserve boundary; retry when trustworthy
    end
```

This second diagram documents the `DESIGN.md` target, not a current production call path.
