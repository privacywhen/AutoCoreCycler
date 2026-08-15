# GOAL.md

# AutoCoreCycler Project Goal

## Goal

Build an **opt-in Ryzen per-core Curve Optimizer discovery mode** that finds the most-negative **observed passing** CO value for each physical core while approaching instability gradually enough to favour recoverable workload errors over WHEA, freezes, or reboots.

The feature extends a maintained upstream tool. Existing CoreCycler behaviour must remain intact outside the opt-in mode, and future upstream updates must remain practical to integrate.

## Discovery contract

For each unresolved physical core:

1. start from a safe/neutral value or explicitly trusted compatible baseline;
2. apply the candidate under controlled conditions and verify the intended effective map;
3. advance exactly **one CO unit more negative** only after the complete required discovery suite passes;
4. on the first valid attributable instability, stop that core and retain its previous complete-suite pass as the discovery candidate;
5. stop retesting resolved cores while unresolved cores continue.

The `-1` progression is deliberate **fault containment**, not search optimization. Do not replace it with binary search, large jumps, or aggressive-start convergence merely to save runtime.

An observed pass is evidence from that defined exposure, not proof of permanent stability.

## Evidence rules

- Only a complete-suite pass for the same candidate/attempt may advance a core.
- Intended CO is not evidence; the required effective map must be verified before results count.
- Only positive attributable instability may establish a discovery boundary.
- Infrastructure failures and ambiguous WHEA/crash evidence do not become silicon instability.
- A candidate associated with an attributable disruptive failure must not be silently reapplied.
- Reaching the platform CO limit without failure is distinct from observing an adjacent pass/fail boundary.
- Isolated per-core discovery evidence is not combined-map validation.

## Upstream compatibility

Preserve both:

- **behavioural compatibility:** existing CoreCycler functionality still works outside discovery;
- **maintenance compatibility:** discovery remains localized enough that upstream changes can be merged and requalified without effectively maintaining a separate CoreCycler implementation.

Shared upstream behaviour changed by the feature should have focused regression/characterization evidence.

## Priorities

When goals conflict, prefer:

1. trustworthy attribution and evidence;
2. recoverable fault detection and avoidance of unnecessary disruptive instability;
3. existing CoreCycler behaviour and practical upstream maintainability;
4. autonomous progression after initial elevation;
5. durable/resumable state;
6. simplicity and maintainability;
7. runtime efficiency.

## User experience target

For a normal uninterrupted Windows session:

1. start the workflow;
2. approve one normal UAC elevation;
3. allow discovery to continue without routine supervision;
4. receive durable per-core discovery results suitable for later combined-map validation.

A hard reboot may require renewed authorization in v1.

## Non-goals

Do not turn this project into:

- the fastest possible CO search;
- a generalized CPU tuning framework;
- automatic BIOS modification;
- a telemetry platform or new stress-test engine;
- duplicate functionality CoreCycler already provides adequately;
- a persistent privileged daemon or unattended cross-reboot privilege system for v1;
- speculative architecture for unrelated future tuning workflows;
- a heavily divergent fork that effectively requires maintaining CoreCycler independently;
- automatic workload shortening/reordering before evidence justifies it.

Combined-map automation must not complicate or delay trustworthy per-core discovery.

## Success

The project succeeds when discovery can autonomously produce trustworthy per-core candidates, preserve/resume its evidence correctly, avoid invalid boundary decisions, preserve existing CoreCycler behaviour, remain reasonably maintainable against upstream changes, and produce results suitable for independent combined-map validation.

**Prefer the simplest trustworthy system that satisfies this contract.**
