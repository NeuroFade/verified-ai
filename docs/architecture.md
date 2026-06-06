# Architecture

How Verified AI works end-to-end — from provider registration to on-chain proof.

---

## Overview

Verified AI is a two-contract system on Base mainnet:

| Contract | Role |
|---|---|
| **AttestationRegistry** | Immutable record store for every AI inference attestation |
| **ZKVerifier** | Validates zkML proof commitments, linked to the registry |

Together they form a trustless attestation layer: any AI provider can submit a verifiable record of their inference, and any consumer can verify it on-chain without relying on the provider's word.

---

## System diagram

```
 ┌─────────────────────────────────────────────────────────────────────┐
 │                         OFF-CHAIN                                    │
 │                                                                      │
 │  ┌──────────────┐    ┌──────────────────┐    ┌────────────────────┐ │
 │  │  AI Provider │    │   Inference API   │    │    ZK Prover       │ │
 │  │              │───▶│  (e.g. OpenAI,   │───▶│  (Lagrange         │ │
 │  │  registers   │    │   Anthropic, etc) │    │   DeepProve)       │ │
 │  │  on-chain    │    │                  │    │                    │ │
 │  └──────────────┘    └──────────────────┘    └────────────────────┘ │
 │         │                    │                         │             │
 │         │              run inference              generate π         │
 │         │           capture inputHash             (Groth16)          │
 │         │              outputHash                proofHash           │
 │         │                                                            │
 └─────────┼────────────────────────────────────────────────────────── ┘
           │                                               │
           ▼                                               ▼
 ┌─────────────────────────────────────────────────────────────────────┐
 │                          BASE MAINNET                                │
 │                                                                      │
 │  ┌──────────────────────────────┐  ┌───────────────────────────────┐ │
 │  │     AttestationRegistry      │  │         ZKVerifier            │ │
 │  │  0x3dBF622A...281eb          │  │  0xc303124d...c85d3           │ │
 │  │                              │  │                               │ │
 │  │  attest(modelId, in, out, π) │  │  submitProof(attId,           │ │
 │  │  ─────────────────────────▶  │  │    proofHash, pubInputs)     │ │
 │  │                              │  │  ─────────────────────────▶  │ │
 │  │  mapping(bytes32 → Record)   │  │                               │ │
 │  │                              │  │  mapping(bytes32 → ZKProof)  │ │
 │  │  verify(id) → bool      ◀── │──│─ verifyProof(id) → bool       │ │
 │  └──────────────────────────────┘  └───────────────────────────────┘ │
 │                                                                      │
 └─────────────────────────────────────────────────────────────────────┘
           │
           ▼
 ┌─────────────────────────┐
 │      Any Consumer       │
 │                         │
 │  verify(id) → true/false│
 │  getAttestation(id)     │
 │  (permissionless read)  │
 └─────────────────────────┘
```

---

## Data flow

### Step 1 — Provider registration

A provider registers their AI model on-chain with metadata:

```
registerModel(
  modelId:     "gpt-4o-2024-11-20",    // human-readable identifier
  teeType:     "NVIDIA_H100",           // trusted execution environment
  endpoint:    "https://api.example.com/v1",
  modelHash:   keccak256(weightsFingerprint)
)
```

Registration is optional for basic attestation, but required to participate in the reputation system.

### Step 2 — Inference

The provider runs inference off-chain. The inference SDK captures:

```
inputHash  = keccak256(UTF8(prompt))
outputHash = keccak256(UTF8(response))
```

These hashes are the cryptographic commitments that will anchor the proof.

### Step 3 — ZK proof generation

A ZK circuit (Groth16 / BN254) takes:

- **Private inputs:** raw prompt, raw response, model weights fingerprint
- **Public inputs:** `inputHash`, `outputHash`, `modelId`

And produces a proof `π` (~256 bytes) that can be verified without revealing the private inputs.

```
proofHash        = keccak256(π)
publicInputsHash = keccak256(modelHash ++ outputHash)
```

### Step 4 — On-chain attestation

```solidity
// Tx 1: create attestation record
bytes32 attestationId = registry.attest(
  modelId, inputHash, outputHash, zkProof
);

// Tx 2: link ZK proof commitment
bytes32 proofId = verifier.submitProof(
  attestationId, proofHash, publicInputsHash
);
```

### Step 5 — Verification (permissionless)

Any address can verify at any time, forever:

```solidity
bool valid = verifier.verifyProof(attestationId); // true
```

No off-chain service. No trusted party. Pure on-chain state.

---

## Trust model

| Claim | How it's enforced |
|---|---|
| "This model ID ran" | Registered on-chain; provider signed the tx |
| "Input matched this hash" | `inputHash` in attestation; circuit enforces binding |
| "Output matched this hash" | `outputHash` in attestation; circuit enforces binding |
| "The proof is valid" | ZKVerifier stores commitment; full Groth16 check at v2 |
| "This attestation isn't fake" | Immutable on-chain; tx signed by attester's private key |

### Current trust assumptions (v1)

In the current v1 deployment:

1. **Proof commitment stored, not fully verified on-chain.** The `proofHash` and `publicInputsHash` are stored — the pairing check (Groth16 on-chain verification) ships in v2. Commitments are still cryptographically binding.
2. **Provider is trusted to hash faithfully.** The `inputHash` / `outputHash` are computed client-side. With TEE integration, this will be hardware-attested.
3. **Model ID is self-declared.** Registration + reputation will add social verification in v2.

Full trustlessness (no assumptions) is the v2 target.

---

## Gas costs

All operations on Base mainnet:

| Operation | Gas | Cost (@ $2500 ETH, 0.1 gwei) |
|---|---|---|
| `attest()` | ~120,000 | ~$0.003 |
| `submitProof()` | ~80,000 | ~$0.002 |
| `verify()` read | 0 | Free |
| `getAttestation()` read | 0 | Free |

Base L2 makes per-attestation cost economically negligible at scale.

---

## Contract interaction reference

```typescript
// AttestationRegistry — 0x3dBF622ABC705d2Ec0E07EB0fCbb1AbFDe0281eb
registry.attest(modelId, inputHash, outputHash, proof)
registry.getAttestation(id)
registry.verify(id)
registry.getAttestationsByAttester(address)
registry.totalAttestations()

// ZKVerifier — 0xc303124d9276Ea7D3d75E94cE7fE5bd3DBec85d3
verifier.submitProof(attestationId, proofHash, publicInputsHash)
verifier.verifyProof(attestationId)
verifier.isProofVerified(proofHash)
verifier.getProof(proofId)
```

---

## Future architecture (roadmap)

```
v1 (now)   — Attestation record + proof commitment on-chain
v2         — Full Groth16 pairing check on-chain (ZKVerifier upgrade)
v2.1       — TEE-attested hashing (NVIDIA H100 remote attestation)
v3         — Decentralized prover network (multiple independent provers)
v3.1       — AgentCapabilityRegistry (capability-scoped attestations)
v4         — Cross-chain attestation bridge (Ethereum mainnet, Arbitrum)
```
