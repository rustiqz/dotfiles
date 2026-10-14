---
name: greenfield
description: Starting a new project from nothing - the decisions that are expensive to reverse, and the order to make them in. Use when bootstrapping a new repository, service, or client in any language or stack.
allowed-tools: Read, Write, Edit, Glob, Grep
---

On a new project there is no code to survey, so `codex-scout` has nothing to do
and the HLD carries more weight than it ever will again. Every boundary you set
now is one you will be living inside for the life of the project.

## Decide these before writing code

In this order. Each one constrains the next:

1. **What this is not.** The scope you are refusing. Write it down; it is the
   only thing that stops a personal project from growing forever.
2. **The deployment unit.** One binary, a container, a set of services, a
   published package. This determines almost everything downstream — you cannot
   retrofit "single static binary" onto a design that assumed a runtime.
3. **The data model and its owner.** What the source of truth is, and what is
   derived or cached. Get this wrong and every later decision fights it.
4. **The trust boundary.** Who can see what, where secrets live, what the
   threat model is. Security is not a later phase; it is a shape.
5. **Module boundaries.** What owns what. Name the seams you expect to need —
   a trait or interface at a boundary you might swap later costs almost nothing
   now and is a rewrite later.
6. **The verification story.** How you will know it works, before there is
   anything to verify. A project with no test path at the start rarely grows one.
7. **Toolchain and version pins.** Language version, dependency policy, package
   manager. Write them into `AGENTS.md` on day one — an agent will otherwise
   reach for the newest API it knows and you will find out at compile time.

## Write ADRs from the first day

On an existing codebase you can often recover the reasoning by reading around
the decision. On a new one there is nothing to read, and in six months you will
not remember why the trait seam is where it is.

One ADR per decision that was genuinely a choice. Not "we used Postgres" —
"we used Postgres rather than SQLite because X, accepting cost Y." An ADR
listing only benefits is marketing.

## Run the critic before you build

`architecture-critic` earns more on greenfield than anywhere else, because
there is no existing system to catch the design when it is wrong. Run it on the
HLD and take the findings seriously — the cost of acting on them is one
document, and it never gets cheaper than that again.

## Sequence the build to prove the risky part first

Order tasks so the thing most likely to invalidate the design gets built first,
at the smallest scale that proves it. The unfamiliar library, the concurrency
model, the cross-platform boundary — build a walking skeleton of that before
the parts you already know how to write. A design that fails should fail in
week one, not after the comfortable work is done.

## On a stack you are still learning

Delegating implementation in a language you do not yet read fluently is how you
end up with a codebase you cannot maintain. Two guards:

- Keep the LLDs more detailed, not less. If you cannot specify it, you cannot
  review it, and you are trusting the implementer completely.
- Read the diffs yourself even when the tests pass. On an unfamiliar stack the
  point of the first months is that you learn it — delegation that skips the
  reading defeats the reason you chose the project.
