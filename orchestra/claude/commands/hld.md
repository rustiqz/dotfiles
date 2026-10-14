---
description: Draft a High-Level Design for a feature or module
argument-hint: <feature or area name>
---

Draft an HLD for: $ARGUMENTS

1. Ask me any question whose answer would change the design — but ask them all
   at once, not one per turn.
2. Classify the request T0-T4 and say so. If it is T0 or T1, stop - it does not
   need an HLD.
3. If you don't already know this area well, invoke `codex-scout` first. Codex
   surveys the code and returns a map; you stay out of the files. Use the
   `Explore` subagent only for a quick single-question lookup.
4. Apply the `design-docs` skill, plus whichever of `nestjs-backend`,
   `frontend-web`, or `mobile-app` is relevant.
5. Write to `.design/hld/<slug>.md`.
6. For T3/T4, invoke `architecture-critic` against the draft. Present its
   findings unsoftened, then say which you accept and how the design changes.
   Revise the HLD before going further - a flaw fixed here costs one document.
7. End with the task breakdown table and nothing else. Do not start on LLDs
   until I approve the breakdown.
