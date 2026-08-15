# AGENTS.md

Repo-local guidance for Hermes Agent and other coding agents working on AutoCoreCycler. Keep this file high-signal: stable project context and agent behaviour belong here; detailed requirements and implementation state belong in the linked source-of-truth docs.

## Repo boundary

This is the **AutoCoreCycler development repo**. A separate installed CoreCycler and Hermes CoreCycler skill may exist on the same machine; neither is this repo.

- Work only in this repo unless explicitly authorized otherwise.
- Do not use the installed CoreCycler as the development tree or edit the Hermes skill unless requested.
- Inspect repo path, branch, remotes, relevant source, and `git status` before consequential edits.
- Keep `pr-182` / `pr182-baseline` as reference baselines; normal development belongs on the authorized feature branch.
- Do not add competing root instruction files (`.hermes.md`, `HERMES.md`, `CLAUDE.md`) unless deliberately changing the context-file arrangement.

## Sources of truth

Before implementation, read the documents relevant to the authorized phase:

- `GOAL.md` — requirements, priorities, non-goals
- `DESIGN.md` — current architecture and state model
- `DECISIONS.md` — settled choices
- `PLAN.md` — phase scope and exit gates
- `ISSUES.md` — unresolved questions/conflicts

Do not change a goal or settled decision merely to make implementation easier. Surface a material conflict instead.

## Project invariants

AutoCoreCycler adds an **opt-in descending per-core CO discovery mode** to maintained CoreCycler/PR #182.

- Preserve existing CoreCycler behaviour outside the opt-in mode.
- Advance exactly `-1` only after the complete required discovery suite passes.
- Stability evidence counts only after the required effective CO map is verified as applied.
- Only positive attributable instability establishes a discovery boundary; ambiguous or infrastructure-invalid evidence does not.
- Discovery candidates are not `confirmed`, `knownGoodValues`, or mixed-map validation results.
- Keep future upstream CoreCycler updates practical to integrate.

## Development discipline

- **Inspect before acting.** Prefer current repo evidence over prior chat summaries or assumptions.
- **Resolve cheaply, ask materially.** Investigate ordinary low-risk ambiguity yourself; ask only when the unresolved choice materially affects correctness, architecture, authorization, hardware behaviour, or irreversible work.
- **Prefer the smallest durable change.** Reuse existing CoreCycler/PR #182 mechanisms when adequate. Avoid speculative features, duplicate machinery, unnecessary configurability, and broad refactors.
- **Minimize semantic divergence from upstream.** Prefer localized extensions or small clean seams over copied upstream logic, rewrites, or feature state scattered through unrelated paths.
- **Characterize shared behaviour before changing it.** If a shared upstream path lacks adequate regression coverage, first capture the smallest focused test that establishes the behaviour being modified. Do not build a broad CoreCycler test suite merely for completeness.
- **Keep scope surgical.** Match existing style; do not reformat or clean up unrelated upstream code. Keep any necessary upstream bug fix separable from feature work when practical.
- A small shared refactor is acceptable when it creates a cleaner extension seam and preserves legacy semantics. Optimize for low semantic divergence and future merge-conflict surface, not raw lines changed.

Classify new findings as `BLOCKER`, `MUST_FIX_CURRENT_PHASE`, `LATER`, or `NOT_A_PROBLEM`. Only the first two may expand current-phase work.

## Phase workflow

For each authorized phase:

1. confirm objective, scope, and exit gate;
2. inspect the relevant implementation and shared upstream seams;
3. establish focused baseline coverage where needed;
4. implement the smallest coherent change;
5. run targeted feature and affected-legacy verification;
6. review the diff for scope and unnecessary upstream divergence.

Do not start the next phase until the current gate has fresh evidence or a genuine blocker is documented.

## Verification and boundaries

Verification must be fresh and proportional to the claim.

- Prefer pure/synthetic tests before hardware paths.
- Use project-prescribed verification commands when they exist.
- Review `git diff`, `git diff --check`, and `git status` before claiming completion.
- Report skipped/unavailable checks; passing tests prove only what they exercise.

Unless explicitly authorized, do not run CPU stress workloads, apply CO values, change BIOS/PBO state, create privileged startup/resume machinery, or use the separate installed CoreCycler for hardware testing.

The v1 autonomy target is one normal UAC approval for an uninterrupted Windows session; unattended cross-reboot privilege persistence is not required.

Preserve unrelated user changes and baseline branches. Do not rewrite history, force-push, merge, tag, commit, or publish unless authorized.

## Completion

Report the objective completed, files changed, verification/results, material limitation or blocker, deferred findings, and whether the diff stayed within the authorized phase.

Code written is not completion. Completion requires evidence against the phase gate.
