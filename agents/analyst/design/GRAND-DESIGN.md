# Grand design reference (adopted by the user 2026-11-12)

User statement (2026-11-12, translated): "I am building an exploration platform for RD and DFABI on each platform (Besu & Paladin, Fabric-X, Iroha). The grand design, per the architecture: every bank owns and runs its own stack (its own nodes), decentralization, private transactions R1, R2, R3, etc. Login, password and other non-essential items may be exempted and left for later development." The user adopted the analyst's reply as the reference ("desing dari @analyst ini kita jadikan acuan").

Sources: live read of both clusters 2026-11-12 15:27 CST (analyst); `agents/qa/REGISTER.md` and this folder at platform-ekplorasi@175fab0; exemptions per [EXEMPTIONS.md](EXEMPTIONS.md). Placement: BI, bank-a, bank-b on cluster 1 (ap-southeast-5, Jakarta); bank-c on cluster 2 (ap-southeast-1, Singapore).

Summary: four of five tracks already run every bank's own stack in its own place. Stealth does not yet (no own signer or gateway per bank). Privacy and settlement are proven only for Zeto and Noto so far. What remains: Stealth's own stack, the gateway caller check, and live proof of the token flows and exchanges. Login and password are not on that path.

## 1. Own stack per party

| Track | BI / A / B / C | Remaining gaps (register row or exemption) |
|---|---|---|
| Zeto | YES 4/4: own Besu validator (4 proposers, same height #2,383,547 at 15:27), Paladin node, own Postgres, operator, bank gateway + OPA, bundle server | Registry root = BI (EXEMPT, E7). Key-holder egress open (R17-zeto-other). One Lensa pod holds all 4 client certs (R33, sandbox limit) |
| Noto + Pente | YES 4/4 on the same Paladin nodes | BI notary is a single point (EXEMPT, E4) |
| Stealth | NO 0/4: only a read node per bank | No own signer, no gateway + OPA (R8). Keys on the host Lensa (R1) and in cluster Secrets (R2, user-exempted). Issuer key = deployer key (R3). DFABI custodian online at BI (EXEMPT, E5) |
| Fabric-X | YES 4/4: orderer (4 parts), committer set, own CA, gateway + OPA, FSC node | Any org cert can call any gateway (R32, HIGH). Shared creator identity (R6 = E2). CA admin passwords on one host (R4). Old certs not revoked (R20). Key-holder egress (R17-fabricx, R30, R17b, R17-bankc-fsc). Host Lensa reads the old namespace (R1) |
| Iroha 3 | YES 4/4: own peer, driver, gateway + OPA | 2-of-3 auditors not proven (R8, S13). Fixed lane author (EXEMPT, E1 / R29). BI governance seed on the host (R10) |

## 2. R1 / R2 / R3

R1 = only BI, sender and receiver see a transaction. R2 = works with BI offline. R3 = both legs settle or neither does. NOT PROVEN = not yet run on the new stack; it counts as open, not as FAIL.

| Track | R1 | R2 | R3 |
|---|---|---|---|
| Zeto | PASS for outsiders (layer 7); BI passive view EXEMPT (E3) | PARTIAL: chain and Lensa PASS (R2-chain, R2-Lensa); BI reports lost until the re-send (R28); Lensa gate blocks writes when any node is down (R21) | NOT PROVEN: DvP gated on R28 |
| Noto + Pente | PASS (layer 7) | EXEMPT (E4) | NOT PROVEN on the new stack |
| Stealth | NOT PROVEN; design gap: nothing forces the viewing-key handover to BI ([ARCHITECTURE-stealth.md](ARCHITECTURE-stealth.md) hard limit 2, line 133) | RD NOT PROVEN; DFABI EXEMPT (E5) | NOT PROVEN |
| Fabric-X | FAIL until R32 is published (cross-party gateway access); E2 covers only the shared creator identity | NOT PROVEN; design ALIGNED, BI down about 260 s slower ([ARCHITECTURE-fabricx.md](ARCHITECTURE-fabricx.md) line 146) | NOT PROVEN; design ALIGNED (line 147) |
| Iroha 3 | PARTIAL: legs readable inside the dataspace (EXEMPT, E8); auditor proof pending | BI validator EXEMPT (E1 / R29); BI auditor offline NOT PROVEN (S13) | NOT PROVEN on the new stack; design ALIGNED ([ARCHITECTURE-iroha3.md](ARCHITECTURE-iroha3.md) line 4; E9) |

## 3. Essential and non-essential register rows

Waived as later development (non-essential): R14 (database password log hygiene), R15 (public images), R16 (past 2-minute residual), R19-b, R19-e, R19-f, R19-g (process slips), R23 (CI-skipped deploy), R27 (CI snippet), and login, TOTP, password, sessions, throttle and audit UI (limit recorded in R33).

Rules that stay in force but are not work items: R5 (no co-located admin keys), R19-c, R19-d (no host builds, user order), R25 (memory rule), R26 (no host deploys).

Must not drop (essential):

- Key holding: R1 (with the S22 destruction record), R2 (S22 record), R3, R4, R10, R20, and the R33 end step before real data.
- Own stack and decentralization: R8, R22 (bank-c not applied), R11, R12, R13, R19 (a party admin per bank is part of "each bank runs its stack"; end step, does not block flows).
- Privacy and settlement: R32, R28, R21.
- Key-holder egress: the R17 family, R30, R17b.
- R19-a: another team's namespace; user-only, not waivable by the team.

Register corrections (analyst ruling; qa applies them in its register): R6 is EXEMPT via E2 (merged in [EXEMPTIONS.md](EXEMPTIONS.md)), no longer "exemption pending". R9 is CLOSED: S5b done, 4 validators live, 4 proposers at 15:27.

## 4. Critical path

1. Stealth own stack: a signer and a gateway + OPA per bank; keys move off the host Lensa. Then live: RD issue, transfer, DvP; one DFABI transfer (E5); the BI viewing-key handover. Owner: besu.
2. R32 publish: caller-identity binding on all four gateway sets, with a cross-party 403 test per set. Unlocks Fabric-X R1. Owner: fabric.
3. Fabric-X flows with each party's own identity: issue, award, transfer, swap, plus one run with BI down (R2, R3). Retire the host-Lensa Fabric-X path. Owners: fabric, fe.
4. Iroha: 2-of-3 auditors proven with BI's auditor offline, then a native DvP on the new stack. Owner: iroha.
5. Zeto re-send (R28) and the Lensa gate fix (R21); this unlocks the Zeto DvP. Then re-prove the Noto/Pente DvP live. Owners: besu, fe.

In parallel, not blocking: R4, R20 and R1-S22 key closes; R22 on bank-c; R17 egress.

Hard gates that stay: P1-P6 ([README.md](README.md)), the user-only list, no custom code in official components, builds only in CI or pods.
