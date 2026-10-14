<!-- Append to AGENTS.md in a Rust project with a pinned toolchain (e.g. Monitra).
     This is the single most-violated constraint when delegating Rust: an agent
     reaches for the newest API or crate version it knows, and you find out at
     compile time after a full delegation has been spent. -->

## Toolchain — hard constraint

This project pins **rustc <VERSION>**. It is not negotiable and not a
suggestion.

- Do not use any std API stabilized after that version.
- Do not bump any dependency in `Cargo.toml`. The pin block is deliberate;
  several crates have newer versions that require a newer rustc.
- Do not add a dependency without it being named in the spec.
- If the task cannot be done within the pinned toolchain, that is a **blocker**.
  Report it. Do not bump the pin to make it work.

Verify with the project's own toolchain, not whatever is on PATH:

```
cargo +<VERSION> build
cargo +<VERSION> clippy -- -D warnings
cargo +<VERSION> test
```

A zero-warning build is the standard here. Warnings are failures.

## Rust conventions

- No `unwrap()` or `expect()` outside tests and `main`. Propagate with `?`.
- No `unsafe` without an explicit `// SAFETY:` comment stating the invariant.
- Errors are typed. No `Box<dyn Error>` in library code.
- Prefer borrowing over cloning; if you clone to satisfy the borrow checker,
  say so in `deviations` so it can be reviewed.
