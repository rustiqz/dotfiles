---
description: Send an audited LLD to Codex, verify the result, and report
argument-hint: <path to LLD>
---

Delegate: $ARGUMENTS

Follow the `delegate-to-codex` skill.

1. Run the pre-delegation checks. Stop if any fail.
2. Invoke the `codex-implementer` subagent with the spec path.
3. When it returns, invoke the `verifier` subagent on the spec's acceptance
   commands. Do not take the report's word for it.
4. Review the diff yourself — `git diff --stat`, then the files that matter.
5. Report: what landed, verification result, deviations, and what needs a
   decision from me.

Do not start the next task.
