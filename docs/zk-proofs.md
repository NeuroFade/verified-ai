# ZK Proofs

How Verified AI uses zero-knowledge proofs to make AI inference trustless.

---

## The problem

When an AI model produces an output, there's currently no way to prove:
- **Which model** produced it (not a different, cheaper model)
- **What the exact input was** (no prompt injection or tampering)
- **What the output was** (not a fabricated response)

Without revealing the model weights, system prompts, or user data.

ZK proofs solve this.

---

## What is a ZK proof?

A zero-knowledge proof lets the **prover** convince the **verifier** that a statement is true — without revealing *why* it's true or any underlying private data.

In Verified AI's context:

> *"This specific model (M) received this input (I) and produced this output (O)"*  
> — provable on-chain, without exposing M's weights or raw I/O

---

## Proof system

Verified AI uses **Groth16** — the most gas-efficient ZK proving system, enabling economically viable on-chain verification.

| Property | Value |
|---|---|
| Proving system | Groth16 |
| Elliptic curve | BN254 |
| Proof size | ~256 bytes |
| On-chain verification gas | ~250,000 |
| Verification cost on Base | ~$0.01 |
| Trusted setup | Hermez Phase 2 ceremony (1000+ participants) |

---

## Proof flow

### 1 — Inference (off-chain)

```
User sends prompt P to model M
  ↓
M produces response R
  ↓
System captures:
  inputHash  = keccak256(P)
  outputHash = keccak256(R)
  modelHash  = keccak256(model weights fingerprint)
```

### 2 — Proving (off-chain, ~2-10 seconds)

```
ZK circuit receives:
  Private inputs: raw P, raw R, model weights hash
  Public inputs:  inputHash, outputHash, modelId
  ↓
Groth16 prover generates π (proof)
  ↓
proofHash       = keccak256(π)
publicInputsHash = keccak256(modelHash ++ outputHash)
```

### 3 — Attestation (on-chain)

```
AttestatioRegistry.attest(modelId, inputHash, outputHash, proof)
  ↓
attestationId = keccak256(attester, modelId, inputHash, outputHash, timestamp)
  ↓
ZKVerifier.submitProof(attestationId, proofHash, publicInputsHash)
  ↓
proof stored as commitment — verifiable by anyone
```

### 4 — Verification (on-chain, permissionless)

```
ZKVerifier.verifyProof(attestationId) → true / false
```

---

## Privacy guarantees

| Data | Visible on-chain? |
|---|---|
| Model weights | ❌ Never |
| System prompt | ❌ Never |
| Raw user prompt | ❌ Never |
| Raw AI response | ❌ Never |
| Model identifier | ✅ Public |
| Input hash | ✅ Public |
| Output hash | ✅ Public |
| Proof hash | ✅ Public |
| Attester address | ✅ Public |
| Timestamp | ✅ Public |
| Attestation validity | ✅ Public |

---

## Circuit design

The ZK circuit enforces:

1. **Model binding** — Proof is cryptographically tied to a specific model version hash
2. **Input/output binding** — `keccak256(prompt) == inputHash` must hold inside the circuit
3. **Execution integrity** — Model weights hash matches the registered model fingerprint
4. **Non-replayability** — Nonce prevents proof reuse across attestations

---

## Generating proofs (SDK)

The SDK handles proof generation automatically inside `attest()`:

```typescript
const result = await client.attest({
  model: 'gpt-4o',
  prompt: 'Your prompt',
  response: 'Model response',
});
// ZK proof generated + submitted in one call
```

For advanced use (custom provers):

```typescript
import { ZKProver } from 'verified-ai-sdk/zk';

const prover = new ZKProver();
const proof = await prover.generate({
  modelId: 'gpt-4o',
  prompt: 'Your prompt',
  response: 'Model response',
});

console.log(proof.bytes);          // Raw proof (~256 bytes, hex)
console.log(proof.hash);           // keccak256 of proof
console.log(proof.publicInputs);   // Public inputs for on-chain verification

// Submit manually
await client.submitProof({
  attestationId,
  proofHash: proof.hash,
  publicInputsHash: proof.publicInputs.hash,
});
```

---

## Trusted setup

Verified AI uses proofs generated from the **Hermez Phase 2 ceremony** — one of the largest trusted setups ever conducted, with 1000+ participants. Even a single honest participant ensures security of the entire setup.

The ceremony transcript is publicly verifiable:
- [Hermez Ceremony transcript](https://hermez.io/hermez-cryptographic-setup-ceremony-transcript/)
- Circuit-specific setup: published at mainnet launch

---

## Current limitations

| Limitation | Status |
|---|---|
| Full Groth16 on-chain verifier | Roadmap Q3 2025 |
| Decentralized prover network | Roadmap Q4 2025 |
| GPU-accelerated proving | Research |
| Model support (requires inference hooks) | Growing list |

For now, proof commitments (hashes) are stored on-chain and verified against submitted public inputs. Full on-chain pairing check ships with the Groth16 verifier upgrade.
