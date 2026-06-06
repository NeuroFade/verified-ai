# Verified AI

> **On-chain attestation and zkML proof verification for AI inference.**  
> SSL certificates for the age of agents.

[![License: MIT](https://img.shields.io/badge/License-MIT-white.svg)](LICENSE)
[![Built on Base](https://img.shields.io/badge/Built%20on-Base-0052FF.svg)](https://base.org)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.24-gray.svg)](https://soliditylang.org)
[![Deployed](https://img.shields.io/badge/Status-Mainnet-30d158.svg)](#contracts)

---

## What is Verified AI?

AI systems are increasingly making consequential decisions — but there's no way to prove *which model* ran, *what input* it received, or *what output* it produced. Verified AI solves this with a two-contract system on Base:

1. **AttestationRegistry** — immutable on-chain record for every AI inference
2. **ZKVerifier** — validates zkML proof commitments without revealing model weights

The result: cryptographic proof that a specific AI model produced a specific output, verifiable by anyone, trusted by no one.

---

## Contracts (Base Mainnet)

| Contract | Address | BaseScan |
|---|---|---|
| `AttestationRegistry` | `0x3dBF622ABC705d2Ec0E07EB0fCbb1AbFDe0281eb` | [View ↗](https://basescan.org/address/0x3dBF622ABC705d2Ec0E07EB0fCbb1AbFDe0281eb) |
| `ZKVerifier` | `0xc303124d9276Ea7D3d75E94cE7fE5bd3DBec85d3` | [View ↗](https://basescan.org/address/0xc303124d9276Ea7D3d75E94cE7fE5bd3DBec85d3) |

---

## Architecture

```
Provider                  Chain                     Consumer
   │                        │                           │
   ├─ register()            │                           │
   │  (model, TEE, url) ───▶│ AttestationRegistry       │
   │                        │                           │
   ├─ run inference         │                           │
   ├─ generate zkML proof   │                           │
   ├─ attest()             │                           │
   │  (model, inputHash, ──▶│ AttestationRegistry       │
   │   outputHash, proof)   │  └── stores attestation   │
   │                        │                           │
   ├─ submitProof()         │                           │
   │  (attestationId,  ────▶│ ZKVerifier                │
   │   proofHash,           │  └── validates + stores   │
   │   publicInputsHash)    │                           │
   │                        │                           │
   │                        │◀──── verify(id) ─────────┤
   │                        │       └── true / false    │
```

---

## Quick Start

### Install SDK

```bash
npm install verified-ai-sdk
```

### Attest an inference

```typescript
import { VerifiedAI } from 'verified-ai-sdk';

const client = new VerifiedAI({
  network: 'base-mainnet',
  privateKey: process.env.PRIVATE_KEY!,
});

// Attest — generates ZK proof + stores on-chain
const result = await client.attest({
  model: 'gpt-4o',
  prompt: 'Explain quantum computing',
  response: 'Quantum computing uses...',
});

console.log('Attestation ID:', result.id);
console.log('TX:', `https://basescan.org/tx/${result.txHash}`);
```

### Verify any attestation

```typescript
// Anyone can verify — no signer required
const isValid = await client.verify(result.id);
console.log(isValid); // true

const record = await client.getAttestation(result.id);
console.log(record.modelId);    // 'gpt-4o'
console.log(record.timestamp);  // block timestamp
console.log(record.valid);      // true
```

### Direct contract interaction (ethers.js)

```typescript
import { ethers } from 'ethers';

const provider = new ethers.JsonRpcProvider('https://mainnet.base.org');
const signer = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);

const registry = new ethers.Contract(
  '0x3dBF622ABC705d2Ec0E07EB0fCbb1AbFDe0281eb',
  REGISTRY_ABI,
  signer
);

const tx = await registry.attest(modelId, inputHash, outputHash, zkProof);
await tx.wait();
```

---

## SDK Reference

### `new VerifiedAI(config)`

```typescript
interface Config {
  network: 'base-mainnet' | 'base-sepolia';
  privateKey?: string;   // required for write ops
  rpcUrl?: string;       // optional override
}
```

### Methods

| Method | Description | Returns |
|---|---|---|
| `attest(params)` | Submit attestation + ZK proof | `AttestationResult` |
| `verify(id)` | Check attestation validity | `boolean` |
| `getAttestation(id)` | Fetch attestation record | `Attestation` |
| `getProof(id)` | Fetch proof commitment | `ZKProof` |
| `listAttestations(addr)` | All attestations by provider | `Attestation[]` |
| `watchAttestations(cb)` | Real-time event listener | `() => void` |

---

## ZK Proof System

Verified AI uses **Groth16** (BN254 curve) — the most gas-efficient proving system for on-chain verification:

| Property | Value |
|---|---|
| Proof size | ~256 bytes |
| On-chain verification | ~250K gas |
| Proving time | 2–10 seconds |
| Setup | Hermez Phase 2 ceremony |

Privacy guarantees:
- ✅ **Public**: model ID, input hash, output hash, timestamp, validity
- ❌ **Private**: model weights, raw prompt, raw response, system prompt

---

## Contracts

### AttestationRegistry

```solidity
// Submit an attestation
function attest(
    string calldata modelId,
    bytes32 inputHash,
    bytes32 outputHash,
    bytes calldata zkProof
) external returns (bytes32 attestationId);

// Query
function getAttestation(bytes32 id) external view returns (Attestation memory);
function verify(bytes32 id) external view returns (bool);
function totalAttestations() external view returns (uint256);
```

### ZKVerifier

```solidity
// Submit ZK proof
function submitProof(
    bytes32 attestationId,
    bytes32 proofHash,
    bytes32 publicInputsHash
) external returns (bytes32 proofId);

// Verify
function verifyProof(bytes32 attestationId) external view returns (bool);
function isProofVerified(bytes32 proofHash) external view returns (bool);
```

---

## Roadmap

- [x] AttestationRegistry — Base mainnet
- [x] ZKVerifier — Base mainnet
- [x] TypeScript SDK (verified-ai-sdk)
- [ ] Full Groth16 on-chain verifier
- [ ] Lagrange DeepProve integration
- [ ] Decentralized prover network
- [ ] AgentCapabilityRegistry
- [ ] AIActCompliance module
- [ ] Subgraph indexer
- [ ] REST API gateway

---

## Docs

| Guide | Description |
|---|---|
| [Getting Started](docs/getting-started.md) | Install, configure, first attestation |
| [SDK Reference](docs/sdk-reference.md) | Full API reference with types |
| [Contracts](docs/contracts.md) | ABI, interfaces, deployment addresses |
| [ZK Proofs](docs/zk-proofs.md) | ZK circuit design, proof flow, privacy model |
| [Examples](docs/examples.md) | Real-world patterns: Next.js, CLI, batch, events |

---

## Development

```bash
git clone https://github.com/NeuroFade/verified-ai
cd verified-ai

# Install foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Build
forge build

# Test
forge test

# Deploy (requires funded wallet)
export PRIVATE_KEY=0x...
forge create src/AttestationRegistry.sol:AttestationRegistry \
  --rpc-url https://mainnet.base.org \
  --private-key $PRIVATE_KEY \
  --broadcast
```

---

## Contributing

Pull requests welcome. Open an issue first for major changes.

1. Fork the repo
2. Create a feature branch (`git checkout -b feat/my-feature`)
3. Commit with conventional commits
4. Open a PR against `main`

---

## License

MIT — see [LICENSE](LICENSE)

---

<p align="center">
  Built on <a href="https://base.org">Base</a> · 
  <a href="https://basescan.org/address/0x3dBF622ABC705d2Ec0E07EB0fCbb1AbFDe0281eb">AttestationRegistry</a> · 
  <a href="https://basescan.org/address/0xc303124d9276Ea7D3d75E94cE7fE5bd3DBec85d3">ZKVerifier</a>
</p>
