# Reproducibility — the prompts that produce `gcd`

Produced **cold**: an isolated agent that did not know the kit was coming first wrote the
program (self-contained — no libraries or builtins); then a clean-context agent learned
the Formal Verification Kit and ran `/formalize` + `/verify` on it. *(Automated here by an
isolated-coder -> kit-user harness; the prompts below are the human-reproducible recipe —
what you would paste, in order, in a fresh session.)*

## The prompts

```text
[P1]  Write `gcd(a, b)` returning the greatest common divisor of two non-negative integers via the Euclidean algorithm (`while b: a, b = b, a % b`). Self-contained — operators only.

[P2]  Learn the Formal Verification Kit at https://github.com/grosu/formal-verification-kit:
      read its AGENTS.md and follow the BOOTSTRAP (read the knowledge/ primers).
      Tell me when you're ready.

[P3]  Before writing any files, walk me through the specification and the
      invariant(s) / circularity you intend to write, and any concerns — no artifacts yet.

[P4]  run /formalize

[P5]  If I say /verify, what exactly will you verify — given any bugs or edge cases
      you've already found?

[P6]  run /verify
```

Append *"be exhaustive and adversarially verify this"* to P4/P6 to make the agent
cross-check itself.

## Produced

- **P1** -> [`gcd.py`](gcd.py) (self-contained)
- **P4** -> [`mini-python.k`](mini-python.k), [`mini-python-spec.k`](mini-python-spec.k), [`SPEC.md`](SPEC.md), [`FINDINGS.md`](FINDINGS.md)
- **P6** -> [`PROOF.md`](PROOF.md) (constructed, not machine-checked) + the test-redundancy report
