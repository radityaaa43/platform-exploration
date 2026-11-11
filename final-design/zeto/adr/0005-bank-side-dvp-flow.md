# 0005. Cross-bank DvP when each bank runs its own client
Date: 2026-11-11
Status: proposed
Deciders: user

## Context
One process drives both DvP legs today: seller and buyer legs, Atom create, delegateLock per party, execute by the buyer (besu@9890701:zeto/src/flows.ts:118-131; frontend@28c8bdb:server/src/adapters/zeto.ts:34,280-281 builds a client for all four nodes). Objective "self-submit" and analyst principle 1 want each bank to talk only to its own node. Upstream describes the Atom setup, approve, execute sequence and that any party may execute (paladin@v1.0.0:doc-site/docs/architecture/atomic_interop.md:46-117); it has no protocol for passing lockId, calldata and the Atom address between banks. The analyst marks this a flow redesign that needs the user (ARCHITECTURE DELTA 7); messaging may use Paladin group messages, the choreography is project application code.

## Decision
Left to the user. PLAN S18 stays BLOCKED(bank-side DvP flow).

## Alternatives Considered
- Keep one coordinator for DvP (today, cost 0). Pros: works, tested (R3 proof). Cons: one process holds both banks' client identities, which the objective rejects; Lensa stays a signer-equivalent.
- Per-bank client plus bank-to-bank messages over Paladin group messages (cost L). Pros: no new transport, each bank only its own node, upstream-supported messaging. Cons: new project choreography (message schema, timeouts, retries); the Atom.cancel window grows (ADR 0003); BI must be reachable for the report group (no change from today).
- Per-bank client plus a project API between bank clients (cost L). Pros: simpler retries. Cons: a second trust channel beside Paladin, a service to run and secure per bank; not found in upstream docs [unverified].

## Consequences
- Only the first option leaves S18 with no work and keeps Lensa as the cross-bank coordinator until Noto and Stealth DvP decide the same way (noto-pente `executeOutright`, stealth DvP).
- Any other option adds a Lensa pointer change beyond S19 and a qa flow in VERIFY.md.
