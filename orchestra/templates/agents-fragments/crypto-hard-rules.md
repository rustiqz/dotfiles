<!-- Append to AGENTS.md in any project handling encryption, key derivation, or
     authentication (e.g. a zero-knowledge password manager).

     Rationale: a model will produce plausible-looking cryptographic code on
     request. It compiles, the tests pass, and it is wrong in a way that no
     test in the suite can detect. This is the one area where the normal
     delegate-and-verify loop does not work, because verification cannot
     catch the failure. -->

## Cryptography — do not implement

You must **not** write, modify, or "optimize" any of the following. Report as a
blocker instead:

- encryption or decryption routines
- key derivation, key stretching, or parameter selection
- random number generation or nonce/IV/salt generation
- authentication, signature, or MAC logic
- constant-time comparison
- anything that changes the shape or contents of a stored ciphertext
- anything that changes what is sent to the server

You **may** wire up calls to a vetted library exactly as the spec describes:
the algorithm, the library, the parameters, and the call sequence all come from
the spec. If the spec does not name a parameter, do not choose one.

## Why this rule exists

Cryptographic code that is wrong compiles, runs, and passes tests. The failure
is silent and not detectable by the verification this project uses. That makes
it the one category where "it works" proves nothing.

## Zero-knowledge invariants

These hold everywhere in this codebase. A change that violates one is a blocker
even if the spec appears to ask for it:

- The server never receives the master password, or anything derived from it
  that could be used to decrypt.
- Plaintext vault contents never leave the client. Never logged, never sent in
  telemetry, never included in an error message or crash report.
- Anything sent to the server is already encrypted client-side, including
  metadata the spec designates as sensitive.
- Keys live in memory no longer than needed, and are not written to disk,
  logs, or persistent storage.

If a task cannot be completed without breaking one of these, it is a design
problem. Report it.
