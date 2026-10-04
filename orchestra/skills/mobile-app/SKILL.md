---
name: mobile-app
description: Design and implementation conventions for mobile apps - navigation, offline and sync behaviour, background work, push notifications, platform differences, and release constraints. Use when designing or building mobile screens, navigation, offline support, or native integrations.
allowed-tools: Read, Write, Edit, Glob, Grep
---

Mobile differs from web in four ways that must be decided at design time, not
discovered during implementation.

## 1. The network is not there

Assume every request can fail, hang, or arrive twice. An LLD must state, per
screen:

- What renders with no network and a cold cache
- What renders with no network and a warm cache
- Whether writes queue offline, and if so: the queue's ordering guarantee, its
  conflict-resolution rule, and what the user sees while items are pending

"It syncs" is not a specification. Name the strategy: last-write-wins,
server-authoritative, or per-field merge — and what happens to a conflict.

## 2. The process dies

The OS can kill the app between any two lines. Therefore:

- Anything the user has typed survives backgrounding, or you lose their work.
- In-flight mutations are idempotent with a client-generated key, because the
  retry after a kill is indistinguishable from a duplicate.
- Background work has a hard time budget and must checkpoint. Both platforms
  will terminate a long background task without ceremony.

## 3. Navigation is state

- Define the navigator tree in the HLD, including deep links and the back
  behaviour of every stack. Retrofitting deep links onto an ad-hoc navigator is
  a rewrite.
- Every screen is reachable by URL, and a cold start into any deep link renders
  correctly. Test this explicitly; it is where most navigation bugs live.
- Params carry ids, not objects. A serialized object in nav state goes stale.

## 4. You cannot hotfix

A bad release is live for days. So:

- Feature-flag anything risky, with the flag readable before first render.
- Version the API contract and keep the previous version working. Old app
  builds will be talking to your backend for months.
- The LLD states the minimum supported app version for any new endpoint.

## Platform differences worth specifying

State these per screen rather than leaving them to the implementer: safe-area
handling, keyboard avoidance behaviour, back gesture vs back button, permission
prompt timing and the denied-permission path, and haptics.

Permissions in particular: never request on app launch. Request at the moment
of use, with a pre-prompt explaining why, and design the flow for permanent
denial — that path is real and usually unimplemented.

## Testing

- Unit-test logic and reducers off-device.
- Anything touching navigation, permissions, or persistence needs a real device
  test on both platforms. Simulators lie about permissions, background
  behaviour, and keyboard handling.
