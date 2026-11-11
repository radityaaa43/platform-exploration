# 0004. DFABI controllability: keep the controller or renounce control
Date: 2026-11-11
Status: proposed
Deciders: user

## Context
`DfabiBond` sets `isControllable` true in the ERC1400 constructor (`besu@9890701:stealth-address/src/vendor/universal-token/ERC1400.sol:193`). `renounceControl()` is owner-only and irreversible (`:710-713`). Controller power is `_isControllable && _isController[op]` (`:1150`); today the only controller is the shared deployer account, so BI can force-move any holder's DFABI (CURRENT.md sections 2 and 10). PLAN S12 moves the controllers with `setControllers([new])` (`:745`). `DvPEscrow.sol:131` says a failed bond refund "waits for the controller", so removing every controller, or renouncing control, leaves such refunds stranded.

## Decision
Left to the user. PLAN S12 moves the controllers in either case; only the `renounceControl` option is BLOCKED(bond controllability) until the user chooses.

## Alternatives Considered
- (a) Keep the bond controllable, the custodian as controller (default; no extra call beyond S12). Pros: refunds of failed escrows keep working; the regulator-style force-transfer power stays for legal or error correction. Cons: one party can move any holder's DFABI: a concentration of power that R1/R2 do not cover.
- (b) `setControllers([])` (no controller, still renounceable later). Pros: no force-move today. Cons: a failed bond refund in `DvPEscrow` has nobody to resolve it (`:131`); reversible only by the owner calling `setControllers` again.
- (c) `renounceControl()` (irreversible; `ERC1400.sol:712-713`). Warning (DELTA 4a): this is not a role move and falls outside the "only role holders move" rule (ARCHITECTURE-stealth.md:66), so it needs the user's explicit decision. Pros: the bond is permanently non-controllable, holders cannot be force-moved. Cons: cannot be undone; refunds waiting for the controller are stranded; no recovery from a lost holder key or a wrong transfer.

## Consequences
- (a): S12 as written; CONTRACTS.md keeps `isControllable` true.
- (b): S12 plus an empty controller set; DvP refund failure handling must be documented before any escrow with a bond leg is created.
- (c): S12 plus an irreversible call; analyst re-scores controller power and the DvP refund path first.
