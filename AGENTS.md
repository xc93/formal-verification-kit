# AGENTS.md — Formal Verification Kit

A provider-neutral kit for adding **formal specifications** (K reachability claims + matching-logic conditions) to code and **constructing a correctness proof** for them. Two commands:

- **`/formalize`** — write the specs plus a plain-language Findings report.
- **`/verify`** — construct the proof, emit the `.k` artifacts and `kompile`/`kprove` commands, accumulate proof-derived Findings, and recommend which tests to add, keep, or drop.

Intended loop: problem prompt → conventional code generation → learn this kit → `/formalize` → `/verify` → stop with the evidence package (`INTENT_SPEC.md`, `FORMAL_SPEC_ENGLISH.md`, `SPEC_AUDIT.md`, `PUBLIC_COMPATIBILITY_AUDIT.md`, `FINDINGS.md`, `SPEC.md`, `PROOF.md`, `.k` artifacts, next-iteration guidance). Do **not** regenerate or patch code in this loop unless the user asks for a repair pass; the default goal is feedback that makes the next code-generation pass better.

Two benefits land even for users new to formal verification: fewer tests / faster CI, and surfacing hidden subtle bugs — see [`README.md`](README.md).

## NON-NEGOTIABLE ARTIFACT CONTRACT

FVK is **not** a Markdown-only review. A run that produces only `SPEC.md`, `PROOF_OBLIGATIONS.md`, `FINDINGS.md`, or other prose is **invalid**, however insightful.

Emit the machine-checkable core:

- `mini-<lang>.k` (e.g. `mini-python.k`) — the K semantics fragment being reasoned about;
- `<program>-spec.k` (e.g. `binary-search-spec.k`) — K `claim` blocks for the function contract(s), loop circularit(y/ies), ordering/precedence obligations, and other formal properties;
- `PROOF.md` — the constructed proof referring to those claims;
- exact `kompile` / `kast` / `kprove` commands, labeled **constructed, not machine-checked** unless the toolchain actually returns `#Top`.

Emit the adequacy/audit core that stops you from proving the wrong thing:

- `INTENT_SPEC.md` — intent-only English obligations from the prompt, docs, public tests, names, and default-domain conventions, written **before** accepting candidate/legacy behavior as a spec;
- `PUBLIC_EVIDENCE_LEDGER.md` — the standalone public-evidence ledger, mirrored into `SPEC.md` and into `SPEC-PROVENANCE` comments above the relevant claims;
- `FORMAL_SPEC_ENGLISH.md` — a plain-English paraphrase of every nontrivial K claim/circularity and expected result;
- `SPEC_AUDIT.md` — a claim-by-claim comparison of `FORMAL_SPEC_ENGLISH.md` against `INTENT_SPEC.md`, marking pass/fail/ambiguous;
- `PUBLIC_COMPATIBILITY_AUDIT.md` — public callsite/API/override compatibility for every changed public symbol or virtual dispatch/signature.

A proof that closes against `.k` claims whose English paraphrase does not match public intent proves the wrong contract. Treat it as **invalid/unresolved**, feed the mismatch into `FINDINGS.md`, and never use it to justify `V2 == V1`.

If you cannot write credible `.k` semantics and `.k` claims for the target, stop and report **invalid/unresolved**. Do not silently weaken FVK into natural-language analysis.

In a blackbox code-generator setting these artifacts may be internal evidence and the outside evaluator may score only the final patch. Preserve the formalization/proof bottleneck regardless: prompt intent → `.k` claims → proof obstacles → Findings → next code patch.

## BOOTSTRAP (one-time — skip if already internalized)

Read [`knowledge/intent-evidence.md`](knowledge/intent-evidence.md), [`knowledge/matching-logic.md`](knowledge/matching-logic.md), [`knowledge/k-framework.md`](knowledge/k-framework.md), and [`knowledge/reachability-and-circularities.md`](knowledge/reachability-and-circularities.md) — the one-time "learn public intent + K + matching logic" step. These primers are a fast path for common cases; escalate to [`knowledge/sources.md`](knowledge/sources.md) (papers, matching-logic.org, K docs; optional `--refresh`) when a case isn't covered.

When done, tell the user you've learned the kit and are ready to `/formalize` and `/verify` — then wait for them.

## TRIGGERS

- **`/formalize`** → follow [`commands/formalize.md`](commands/formalize.md).
- **`/verify`** → follow [`commands/verify.md`](commands/verify.md).
- Users usually say **"run /formalize"** / **"run /verify"** (a bare leading `/` can be intercepted as a slash command). Treat *"run /formalize"*, *"please formalize this"*, and *"/formalize the project"* as the same trigger.
- **"use FVK"**, **"use the Formal Verification Kit"**, **"run FVK on this code"**, **"FVK my code"**, or **"use FVK now because the current code is not good enough"** → run the complete black-box loop: learn the kit, `/formalize`, `/verify`, and if the user asked for better/repaired code, apply only the changes the FVK artifacts justify.
- **No arguments** → operate on the whole project / each function in it.

## BLACK-BOX IMPROVEMENT RULES

FVK is self-contained. Do **not** rely on wrapper-specific hints — "the baseline failed", hidden tests, evaluator output, gold patches, benchmark scores, or any prior-attempt status. Allowed evidence: public/user-provided intent, public docs/tests, the current code, and proof/formalization obstacles found while running FVK.

### Normal software-development use

Let the developer keep their usual environment and, at any point, say **"use FVK"** / **"run FVK on this code"** / **"FVK my code"**. Then learn the kit, run `/formalize`, run `/verify`, produce the evidence package, and — if they asked for improvement/repair — revise production code only when the FVK artifacts justify it.

Treat the current project state as the candidate to audit. Building on the ordinary coding context, design notes, public issue text, docs, and source code is fine. The boundary is evidentiary: derive the verdict from public/user-provided intent, source code, public docs/tests, and FVK's own findings — never from hidden evaluator signals or benchmark-only metadata.

### Benchmark and audit use

When comparing an ordinary coding pass against an FVK pass, use the **faithful-baseline + resumed-FVK** protocol:

1. Generate the first repair exactly as a normal coding task, before any FVK files or instructions are present.
2. Freeze that repair's code, notes, and reasoning context.
3. Only then introduce FVK materials, continuing from the same coding session if the platform supports it.
4. Do not reveal test results, evaluator verdicts, gold patches, or whether the first repair passed. Run evaluation only after the FVK phase completes.

This lets FVK build on everything the coding pass learned while keeping the baseline truthful: FVK inherits the coder's public-problem reasoning and candidate patch, but no external success/failure signal.

### Deriving the verdict from FVK artifacts

1. Build the public intent ledger first.
2. Treat the current implementation as a candidate, not the specification.
3. Treat public/in-repo tests **and quoted pre-fix / "before" displays** as evidence, not an oracle. If a test or shown current-behavior output encodes what the public issue or intent describes as buggy, mark that obligation **SUSPECT** and explain the conflict instead of preserving legacy behavior — the bug report *is* the contradiction, so a test you would have to delete to satisfy the intent is a positive bug signal, not a reason to keep V1.
4. If a clean spec or proof obligation cannot be written without forcing legacy behavior, record a Finding; revise the code only when the public intent justifies it.
5. Do not edit tests unless the user asks. The default repair target is production code.
6. Audit against the **full intent** — the whole problem statement plus the docstring / API contract / public names — not just the issue sentence. The driving question is "what is still wrong versus the full intent?", not "is V1 sound on the reported issue?" (Balance: every claimed wrongness must still trace to public-intent evidence.)
7. When the intent obliges a **family** of values/cases, or a value with a specific **output form**, discharge it on the path that form requires and commit every member you can derive. A value shown bare must auto-evaluate on the construction path (not only under `.expand()` / `.simplify()`); a specific-point constant belongs there even if the issue only surfaced it via a workaround transform; and a complex / branch-sensitive member derived from a documented convention is as committable as an easy real one. Applying only the familiar members, or filing them on an opt-in path, leaves the family **un-discharged** — a Finding, not a confirmation.

## TEMPLATE

If `examples/` are available in your workspace, imitate the **closest example by shape** — start from its [catalog](examples/README.md); the reference pair is [`examples/02-sum-up/`](examples/02-sum-up/) (count-up / additive invariant) and [`examples/03-sum-down/`](examples/03-sum-down/) (count-down / remaining-work invariant), each giving the file-by-file template (mini-X semantics, reachability/circularity claims, spec note, findings, constructed proof). If `examples/` are **not** present, follow the file-by-file shape described in [`commands/formalize.md`](commands/formalize.md) and [`commands/verify.md`](commands/verify.md) directly. Either way, for every target build the public intent ledger first, then make the `.k` claims trace back to it. Question any precondition, postcondition, invariant, ordering rule, or proof side condition that comes from the current implementation and looks different from the human requirement — unless it has public intent evidence or is an explicitly named default-domain assumption.

---

Provider-neutral: any agent that reads this `AGENTS.md` works — Claude Code, Copilot CLI, Gemini CLI, Codex, and others.
