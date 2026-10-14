# `orq` — v0 scaffold

The setup commands and the one module that carries the design. Everything else
follows from the HLD's task breakdown.

## Bootstrap

```bash
cargo new --bin orq && cd orq

# Pin the toolchain the same way Monitra does, before writing any code.
# This is what stops an agent reaching for a newer std API mid-delegation.
cat > rust-toolchain.toml <<'EOF'
[toolchain]
channel = "1.75.0"          # match Monitra's pin
components = ["clippy", "rustfmt"]
EOF

# Link it into the design store so the HLD and LLDs live outside the repo,
# exactly as every other project does.
git init && design-store link

# Drop the Rust AGENTS.md fragment in before the first delegation.
cp ~/dotfiles/orchestra/templates/AGENTS.md ./AGENTS.md
cat ~/dotfiles/orchestra/templates/agents-fragments/rust-pinned-toolchain.md >> AGENTS.md
cp ~/dotfiles/orchestra/templates/CLAUDE.project.md ./CLAUDE.md
```

`Cargo.toml` — deliberately thin. Every dependency here is one an agent could
otherwise "helpfully" add a heavier alternative to, so the spec names them:

```toml
[dependencies]
ratatui    = "0.26"    # same as Monitra, so the learning transfers
crossterm  = "0.27"
serde      = { version = "1", features = ["derive"] }
serde_json = "1"        # report.json, usage.json, transcript events
serde_yaml = "0.9"      # LLD frontmatter
anyhow     = "1"        # binary-level errors only
thiserror  = "1"        # typed errors in the model layer
walkdir    = "2"
chrono     = "0.4"

[dev-dependencies]
insta = "1"             # snapshot tests over rendered panes
```

## The seam — `src/source.rs`

This is the module the whole design rests on, and the one to write first after
the scaffold. It is the same reasoning as Monitra's `ResultSink`: the model
layer never touches `std::fs`, so every test runs against in-memory fixtures
with no temp directories and no filesystem ordering flakes.

```rust
use std::path::{Path, PathBuf};

/// Everything the model layer is allowed to know about the outside world.
///
/// Keeping this narrow is the point: if a future pane needs something new,
/// adding a method here is a deliberate decision rather than an `fs::` call
/// appearing somewhere in the UI layer.
pub trait Source {
    /// Project directories under the design store root.
    fn projects(&self) -> Result<Vec<PathBuf>, SourceError>;

    /// Files directly under `<project>/<sub>` — sub is "lld", "hld", "adr".
    fn docs(&self, project: &Path, sub: &str) -> Result<Vec<PathBuf>, SourceError>;

    /// Run directories under `<project>/runs/`, newest first.
    fn runs(&self, project: &Path) -> Result<Vec<PathBuf>, SourceError>;

    /// Read a file to string. Returns Ok(None) when it does not exist, because
    /// a missing report.json is an expected state (the run is still going),
    /// not an error the UI should surface as a failure.
    fn read(&self, path: &Path) -> Result<Option<String>, SourceError>;
}

#[derive(Debug, thiserror::Error)]
pub enum SourceError {
    #[error("design store not found at {0}")]
    StoreMissing(PathBuf),
    #[error("io error reading {path}: {source}")]
    Io { path: PathBuf, source: std::io::Error },
}

pub struct FsSource { pub root: PathBuf }   // ~/design

#[cfg(test)]
pub struct MemSource { pub files: std::collections::BTreeMap<PathBuf, String> }
```

## Stage derivation — `src/model/spec.rs`

The rule the HLD describes, as one function. It is pure: inputs in, stage out,
no I/O. That is what makes the whole stage model testable.

```rust
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Stage {
    Draft,          // the file exists
    Ready,          // spec-auditor passed
    Running,        // a run dir exists, no report yet
    Built,          // report status = completed
    NeedsAttention, // report status = partial | blocked
    Done,           // you stamped it
}

/// Derived, never stored. The filesystem is the source of truth; recomputing
/// this on every scan is cheap and cannot go stale.
///
/// Order matters: an explicit `status: done` wins over everything, then the
/// most recent run's verdict, then the audit flag, then bare existence.
pub fn derive_stage(fm: &Frontmatter, latest: Option<&RunOutcome>) -> Stage {
    if fm.status.as_deref() == Some("done") {
        return Stage::Done;
    }
    match latest {
        Some(RunOutcome::NoReport)            => Stage::Running,
        Some(RunOutcome::Completed)           => Stage::Built,
        Some(RunOutcome::Partial)
        | Some(RunOutcome::Blocked)           => Stage::NeedsAttention,
        None if fm.audited.unwrap_or(false)   => Stage::Ready,
        None                                  => Stage::Draft,
    }
}
```

Spec↔run linkage needs no schema: `codex-task` names run directories
`<timestamp>-<spec-basename>`, so matching on the basename suffix is enough.

## Build order

Follow the HLD's task breakdown. TUI-001 through TUI-007 is v0 — the Runs pane,
the transcript viewer, and the budget trend.

**Then stop and use it for a week.** If the transcript viewer and the ratio
trend are not earning their place by then, the remaining five tasks will not
change that, and the honest move is to leave it at v0.
