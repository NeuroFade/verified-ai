# ZK Proofs

Verified AI uses zero-knowledge proofs to enable trustless verification of AI inference — without revealing the model weights, system prompts, or sensitive input data.

---

## What is a ZK Proof?

A zero-knowledge proof (ZKP) lets one party (the **prover**) convince another (the **verifier**) that a statement is true — without revealing any information beyond the statement's validity.

In Verified AI's context:

> **"This AI model (M) received input (I) and produced output (O)"**  
> — provable without revealing M's weights or the full raw I/O

---

## Proof System

Verified AI uses **Groth16** — the most gas-efficient ZK proving system available, making on-chain verification economically viable.

| Property | Value |
|---|---|
| Proving system | Groth16 |
| Curve | BN254 |
| Proof size | ~256 bytes |
| On-chain verification cost | ~250,000 gas |
| Setup | Universal trusted setup (Hermez ceremony) |

---

## How It Works

### 1. Inference Phase (off-chain)

```
AI Model receives prompt P
    ↓
Model produces response R
    ↓
Execution metadata captured:
  - Model hash (identifies exact model version)
  - Input hash: keccak256(P)
  - Output hash: keccak256(R)
  - Timestamp + nonce
```

### 2. Proving Phase (off-chain)

```
ZK Circuit receives:
  - Private inputs: raw prompt, response, model weights hash
  - Public inputs: inputHash, outputHash, modelId
    ↓
Groth16 prover generates π (proof)
    ↓
Proof size: ~256 bytes
Proving time: ~2-10 seconds (hardware dependent)
```

### 3. Verification Phase (on-chain)

```
ZKVerifier.verifyProof(π, inputHash, outputHash)
    ↓
EVM runs Groth16 pairing check
    ↓
Returns: true / false
    ↓
AttestationRegistry stores result
```

---

## Privacy Guarantees

| Data | On-chain visibility |
|---|---|
| Model weights | ❌ Never revealed |
| System prompt | ❌ Never revealed |
| Raw user prompt | ❌ Never revealed |
| Raw response | ❌ Never revealed |
| Input hash | ✅ Public |
| Output hash | ✅ Public |
| Proof hash | ✅ Public |
| Model ID | ✅ Public |
| Timestamp | ✅ Public |
| Validity | ✅ Public |

---

## Circuit Design

The ZK circuit enforces:

1. **Model binding** — Proof is tied to a specific model version hash
2. **Input/output binding** — `keccak256(prompt) == inputHash` must hold
3. **Execution integrity** — Model weights hash matches registered model
4. **Non-replayability** — Nonce prevents proof reuse

---

## Generating Proofs (SDK)

The SDK handles proof generation automatically:

```typescript
// Under the hood, attest() generates the ZK proof for you
const attestation = await client.attest({
  model: 'gpt-4o',
  prompt: 'Your prompt here',
  response: 'Model response here',
});
```

For advanced use cases, generate proofs manually:

```typescript
import { ZKProver } from 'verified-ai-sdk/zk';

const prover = new ZKProver();
const proof = await prover.generate({
  modelId: 'gpt-4o',
  prompt: 'Your prompt',
  response: 'Model response',
});

console.log(proof.bytes);   // Raw proof bytes (hex)
console.log(proof.hash);    // keccak256 of proof
console.log(proof.valid);   // Pre-verified locally
```

---

## Trusted Setup

Verified AI uses proofs from the **Hermez Phase 2 ceremony** — one of the largest trusted setups ever conducted, with 1000+ participants. A single honest participant ensures security.

The ceremony transcript is publicly verifiable:
- [Hermez Ceremony](https://hermez.io/hermez-cryptographic-setup-ceremony-transcript/)
- Circuit-specific setup: [TBD — will publish when mainnet launches]

---

## Limitations

- **Proving time**: 2-10 seconds per inference (hardware dependent)
- **Model support**: Currently requires models with accessible inference hooks
- **Cost**: ~250k gas per on-chain verification (~$0.01-0.10 on Base)
- **Proof generation**: Currently centralized prover; decentralized provers roadmapped
