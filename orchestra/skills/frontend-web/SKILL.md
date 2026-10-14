---
name: frontend-web
description: Design and implementation conventions for web frontends - component structure, state boundaries, data fetching, accessibility, and API contracts against a NestJS backend. Use when designing or building web UI, React components, pages, forms, or frontend state.
allowed-tools: Read, Write, Edit, Glob, Grep
---

## State boundaries

The decision an LLD must make explicitly, because guessing it produces the
worst frontend code:

| Kind of state | Where it lives |
|---|---|
| Server data (fetched, cached, refetched) | query cache — never mirrored into component state |
| URL-describable state (filters, page, tab, selected id) | the URL |
| Ephemeral UI (open/closed, hover, draft input) | local component state |
| Genuinely cross-cutting (auth session, theme) | one small context |

Copying server data into `useState` is the source of most stale-UI bugs.
If an LLD does not say where a piece of state lives, the implementer will
choose `useState`, and it will be wrong.

## Components

- A component either fetches data or renders it. Not both, once it is past
  trivial. Container/presenter split keeps the presenter testable.
- Props are explicit. No prop spreading into DOM elements — it hides what is
  actually rendered and defeats type checking.
- Derive during render rather than syncing with an effect. An effect whose only
  job is to set state from other state is almost always a bug.
- Every list key is a stable id from the data, never an array index.

## API contracts

- Types for request and response come from one shared source — generated from
  the backend's OpenAPI output, or a shared package. Hand-written duplicates
  drift silently.
- The LLD names the endpoint, the exact response shape, and the error codes the
  UI must handle distinctly. "Show an error" is not a spec.
- Every fetch has all four states designed: loading, empty, error, success.
  An LLD that only describes success is incomplete.

## Forms

- Schema-first validation, with the schema shared with the backend where
  possible. Client validation is UX; the server still validates.
- Submit buttons disable on in-flight requests and the mutation is idempotent
  or guarded, because double-submit will happen.

## Accessibility (non-negotiable, so state it once and enforce it)

- Semantic elements before ARIA. A `<button>` beats a `<div role="button">`.
- Every interactive element is keyboard reachable and has a visible focus state.
- Every form control has a programmatically associated label.
- Colour is never the only carrier of meaning.

## Performance

Measure before optimizing. When an LLD does call for it, be specific: which
component memoizes, which route code-splits, which image loads eagerly. Blanket
`memo()` everywhere costs more than it saves.
