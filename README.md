# Formal Verification Kit

**Prove your code correct for *all* inputs — and let your AI agent do the work.**

Point any coding agent at this repo and run `/formalize` then `/verify` on your code. You get two concrete wins even if you have never heard of "formal verification."

## Benefit 1 — Fewer tests, faster CI

A formally verified function is proven correct for **every** input in its specified domain — not just the handful your unit tests happen to check. So tests that merely re-check input/output cases the spec already covers become **redundant**.

After `/verify`, the kit tells you exactly **which existing tests are now subsumed** by the proof and recommends removing them, with an estimate of the CI time saved. It is conservative and **recommendation-only** — it never deletes a test, and (because the MVP constructs proofs but does not yet machine-check them — see [Honest status](#honest-status)) it advises you to run the emitted `kprove` commands first, or keep the tests until you do. Tests outside the spec's domain, plus termination, performance, and integration tests, are always kept.

## Benefit 2 — Finds hidden, subtle bugs

You get this one **even if you never read a single line of the proof.**

Writing a precise specification routinely flushes out **missing preconditions, forgotten corner cases, and undefined behavior** — the empty input, the zero, the negative number, the off-by-one, the overflow. And the key signal: **if a clean specification is hard or impossible to write, that is itself strong evidence the code has a bug or a forgotten case.**

The kit reports all of this in plain language as a **Findings report** (`input → observed vs expected`), readable by any developer. This is the primary day-one value for people who don't care what formal verification is.

---

## What it is

A standalone, **provider-neutral** repo of plain-markdown files. Nothing to install, no SDK to wire up. Any coding agent that can read a repo (Claude Code, Copilot CLI, Gemini CLI, Codex, …) can use it — the two "commands" are just conventions defined in a markdown file the agent reads.

But FVK is **not** a Markdown-only audit. The markdown teaches the agent what to do; a successful run must still emit the formal core: `.k` semantics, `.k` `claim`s, `PROOF.md`, and exact `kompile`/`kprove` commands. Missing those, the run is invalid/unresolved as FVK.

FVK also has an **adequacy gate**: the agent first writes an intent-only English spec, then paraphrases its own K claims back into English, then compares the two. A proof of `.k` claims that don't say what the prompt says is a proof of the wrong thing — invalid, not a success.

The product shape is a normal software-development protocol, not a benchmark harness. Keep using whatever coding environment you already use; when you want a stronger correctness pass, say **"use FVK"**, **"run FVK on this code"**, or **"FVK my code"**. The agent then formalizes the intended behavior, constructs/checks the proof obligations, reports findings, and revises production code only when the evidence justifies it.

## The automated improvement loop

The intended use is an automatic loop around ordinary code generation:

1. Start with a problem prompt / informal intent.
2. Generate code with your normal AI coding agent.
3. Teach that same agent this kit.
4. Run `/formalize` — infer the intended contract, write K claims, and collect intent/code mismatch Findings. The informal prompt / public problem statement is a first-class spec source: `/formalize` records a public intent ledger, traces each nontrivial claim back to prompt/docs/tests/code evidence, and questions any implementation-derived condition that looks different from the human requirement. It also runs the adequacy round-trip (`INTENT_SPEC.md` → `.k` claims → `FORMAL_SPEC_ENGLISH.md` → `SPEC_AUDIT.md`) plus a `PUBLIC_COMPATIBILITY_AUDIT.md` for public callsites, overrides, and changed APIs.
5. Run `/verify` — construct the proof attempt, collect proof-derived Findings, classify blocked VCs, and identify tests to add, keep, or conditionally remove.
6. **Stop with the accumulated evidence package** (`INTENT_SPEC.md`, `FORMAL_SPEC_ENGLISH.md`, `SPEC_AUDIT.md`, `PUBLIC_COMPATIBILITY_AUDIT.md`, `FINDINGS.md`, `SPEC.md`, `PROOF.md`, `.k` artifacts, next-iteration guidance) so a conventional code generator can produce better code in the next pass.
7. If you asked for better/repaired code, the agent applies only changes the FVK artifacts justify; otherwise it stops at the evidence package.

For day-to-day development there is no benchmark ceremony: the current project state is the candidate FVK audits, using the ordinary design notes, source, public issue text, docs, and public tests already in your environment. The verdict still comes from public/user intent, the code, and FVK's proof/formalization findings — never from hidden evaluator signals.

For benchmark or audit settings (comparing ordinary coding against FVK), use the **faithful-baseline + resumed-FVK** protocol: generate the baseline exactly like an ordinary coding task, with no FVK materials and no evaluator verdicts in context; freeze it; then introduce FVK and continue from the same session. This is FVK's strongest setting — it builds on what the coding pass learned while keeping the baseline truthful. Run evaluation only after both phases complete, and never disclose it to FVK. Full protocol: [`AGENTS.md`](AGENTS.md).

The kit does not silently regenerate or patch code in this loop unless you explicitly ask for a repair pass. The default goal is better intent, better specifications, and better feedback than the original prompt contained.

## Quick start — copy/paste to your agent

Bring this kit to code you've **already written or just generated**. You don't need K, a prover, or anything installed. Paste these to your coding agent in your project.

**Black-box one-liner (the intended product experience):**

> Use the Formal Verification Kit at https://github.com/grosu/formal-verification-kit
> on this code now. Learn its `AGENTS.md`, run the full FVK improvement loop, and
> revise the production code only when the FVK artifacts justify the change.

That instruction must be enough: FVK does not depend on out-of-band hints such as "the baseline failed", hidden evaluator results, gold patches, or benchmark scores. The kit tells the agent how to derive the verdict from public intent, source code, public tests/docs, and proof/formalization findings.

**Step-by-step form:**

**1. Teach it the kit** (any agent — Claude Code, Copilot, Gemini, Codex, …):

> Learn the Formal Verification Kit at https://github.com/grosu/formal-verification-kit
> — read its `AGENTS.md` and follow the BOOTSTRAP (read the `knowledge/` primers) so
> you actually learn it, not just skim the README. Tell me when you're ready.

*If your agent can't browse the web, first run `git clone https://github.com/grosu/formal-verification-kit`, then paste:* "Read `./formal-verification-kit/AGENTS.md` and follow it. Tell me when you're ready."

**2. (Recommended) Sanity-check the plan before any files are written:**

> Before writing any files, walk me through the spec and the loop invariant(s) you
> intend to write, and any concerns — no artifacts yet.

**3. Find the specs — and the bugs:**

> run /formalize

*Say **run /formalize**, not a bare `/formalize` — some agents (Claude Code, etc.) treat a leading `/` as a built-in slash command and reject an unknown one.*

Then read the **Findings report** — the missing preconditions, corner cases, and likely bugs it surfaced. (You get this even if you never read the proof.)

**4. Construct the proof — and accumulate next-iteration feedback:**

> run /verify

Then read the **proof**, the proof-derived additions to the **Findings report**, and the **test-redundancy** recommendation. Stop there unless you explicitly want a repair/regeneration pass; the accumulated findings are the feedback package for the next code-generation iteration.

> **Tip:** append *"be exhaustive and adversarially verify this"* to steps 3–4 to make the agent cross-check itself — the proofs are *constructed, not yet machine-checked* (see [Honest status](#honest-status)).

Both commands need **no arguments** — they operate on the whole project (each function and each loop), with **any** agent that reads `AGENTS.md`.

## What you get

Running `/formalize` then `/verify` produces, alongside your code:

- **Formal specifications** — a K reachability claim (pre/post-condition) per function and a **loop-invariant circularity** per loop, with provenance back to the public prompt / requirements / docs / tests / code that justified the obligation.
- **An adequacy audit** — `INTENT_SPEC.md`, `FORMAL_SPEC_ENGLISH.md`, and `SPEC_AUDIT.md` compare public English intent to the English meaning of the K claims, so FVK doesn't accidentally prove candidate behavior against a candidate-derived spec. `PUBLIC_COMPATIBILITY_AUDIT.md` checks public API, callsite, subclass/override, producer/consumer, and signature compatibility.
- **A constructed correctness proof** — symbolic execution through the semantics, the loop invariant discharged, and the leftover arithmetic checked.
- **`.k` artifacts + run-commands** — the claim/semantics files and the exact `kompile`/`kprove` commands to machine-check the proof later.
- **A Findings report** (Benefit 2) — plain-language bugs, missing preconditions, and corner cases, each with a concrete example; `/verify` extends it with proof-derived findings showing how the next code-generation pass should improve the code or intent.
- **A test-redundancy recommendation** (Benefit 1) — which tests the proof makes redundant, and which to keep.

This is one of a **growing library of worked examples** — browse the catalog in [`examples/`](examples/). Each takes a real function from source code all the way to a constructed proof, file for file. The reference pair is the **`sum-*` cluster** — [`sum-up/`](examples/02-sum-up/) and [`sum-down/`](examples/03-sum-down/) compute the *same* contract (`n·(n+1)/2`) by counting **up** vs. **down**, showing that **the proof obligations differ even when the spec does not**. The vetted, machine-checked examples double as the fine-tuning corpus for the product. See [`examples/README.md`](examples/README.md) for the catalog and how to add your own.

## <a id="honest-status"></a>Honest status (MVP)

A first MVP, optimized for reach. We are upfront about what it does *not* yet do:

- **Constructs the proof, does not run it.** `/verify` builds the proof and emits the exact `kompile`/`kprove` commands, but **does not invoke the toolchain**. Artifacts are labeled **"constructed, not machine-checked."** Test removal is therefore conditioned on you running those commands. (The Findings report does **not** depend on machine-checking and is solid today.)
- **Fragment ("mini-X") semantics.** The kit generates a minimal K semantics covering only the constructs your code actually uses — exactly as the `sum` example builds a *mini Python*. Wiring in **full, real per-language K semantics** (so the literal program is verified against the real language) is the roadmap.
- **Partial correctness by default.** The proof establishes correctness *if* the function returns; termination is surfaced as a recommendation, not proved unless asked.

The [`knowledge/`](knowledge/) primers are a **fast path** for common cases. When your case exceeds them (recursive data structures, binders, concurrency, …), [`knowledge/sources.md`](knowledge/sources.md) is the first-class escalation path — it routes you to the right primary source by topic, and an optional `--refresh` re-fetches them live.

## The vision

The end state is a **fine-tuned model** that already knows full language semantics, the [K framework](https://kframework.org), matching logic, and the proof techniques — so that **one line in yields a verified program out**, with zero extra effort. This MVP approximates that today with bundled knowledge plus an agent-driven workflow.

## Layout

| Path | What it is |
|---|---|
| [`README.md`](README.md) | This file — what it is, the two benefits, how to try it, status, vision. |
| [`AGENTS.md`](AGENTS.md) | Universal entrypoint: bootstrap, the `/formalize` and `/verify` triggers, and the black-box/benchmark protocol. |
| [`commands/formalize.md`](commands/formalize.md) | The `/formalize` workflow (agent-agnostic steps). |
| [`commands/verify.md`](commands/verify.md) | The `/verify` workflow (agent-agnostic steps). |
| [`knowledge/matching-logic.md`](knowledge/matching-logic.md) | Matching-logic primer: patterns-as-sets, the definedness ladder, the proof system. |
| [`knowledge/k-framework.md`](knowledge/k-framework.md) | K primer: config cells, rules, claims, `kprove`, `/Int`. |
| [`knowledge/reachability-and-circularities.md`](knowledge/reachability-and-circularities.md) | Reachability logic, the Circularity rule, the proof recipe. |
| [`knowledge/intent-evidence.md`](knowledge/intent-evidence.md) | Public intent ledger: extract spec obligations from prompts, docs, tests, code, and proof findings. |
| [`knowledge/sources.md`](knowledge/sources.md) | Live source index + the `--refresh` escalation path. |
| [`examples/`](examples/) | A **growing library** of worked examples — [catalog + how-to-add](examples/README.md). The reference pair is [`sum-up/`](examples/02-sum-up/) / [`sum-down/`](examples/03-sum-down/), the template the commands imitate. |
| [`LICENSE`](LICENSE) | MIT. |
| `docs/` | Internal design spec — not part of the user-facing kit. |

## License

[MIT](LICENSE).
