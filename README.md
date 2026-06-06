<div align="center">

<img src="./logo.jpg" alt="Verified AI" width="96" height="96" />

# Verified AI

**On-chain attestation and zkML proof verification for AI inference.**

*SSL certificates for the age of agents.*

<br/>

[![License: MIT](https://img.shields.io/badge/License-MIT-white.svg?style=flat-square)](LICENSE)
[![Built on Base](https://img.shields.io/badge/Built%20on-Base-0052FF.svg?style=flat-square&logo=ethereum)](https://base.org)
[![Solidity](https://img.shields.io/badge/Solidity-0.8.24-363636.svg?style=flat-square)](https://soliditylang.org)
[![Status](https://img.shields.io/badge/Mainnet-Live-30d158.svg?style=flat-square)](#-contracts)
[![npm](https://img.shields.io/badge/npm-verified--ai--sdk-cb0000.svg?style=flat-square)](https://npmjs.com/package/verified-ai-sdk)

<br/>

[**Docs**](docs/README.md) · [**Quick Start**](#-quick-start) · [**Contracts**](#-contracts) · [**Architecture**](docs/architecture.md) · [**Examples**](docs/examples.md) · [**FAQ**](docs/faq.md)

</div>

---

## The problem

AI systems are making consequential decisions — loan approvals, medical triage, legal analysis — but there's no way to prove **which model ran**, **what input it received**, or **what output it produced**.

Without that proof, AI accountability is theater.

## The solution

Verified AI anchors every AI inference to an immutable on-chain record:

```
keccak256(prompt)   →  inputHash   ─┐
keccak256(response) →  outputHash  ─┼─▶ AttestationRegistry (Base mainnet)
Groth16(π)          →  proofHash   ─┘         └── verifiable forever
```

Two deployed contracts. Permissionless reads. No trusted intermediary.

---

## ✦ Contracts

Deployed on **Base Mainnet** — cheap, fast, Ethereum-secured.

| Contract | Address | Explorer |
|---|---|---|
| `AttestationRegistry` | `0x3dBF622ABC705d2Ec0E07EB0fCbb1AbFDe0281eb` | [BaseScan ↗](https://basescan.org/address/0x3dBF622ABC705d2Ec0E07EB0fCbb1AbFDe0281eb) |
| `ZKVerifier` | `0xc303124d9276Ea7D3d75E94cE7fE5bd3DBec85d3` | [BaseScan ↗](https://basescan.org/address/0xc303124d9276Ea7D3d75E94cE7fE5bd3DBec85d3) |

---

## ⚡ Quick Start

```bash
npm install verified-ai-sdk
```

**Attest an inference:**

```typescript
import { VerifiedAI } from 'verified-ai-sdk';

const client = new VerifiedAI({
  network: 'base-mainnet',
  privateKey: process.env.PRIVATE_KEY,
});

const result = await client.attest({
  model:    'gpt-4o',
  prompt:   'Explain quantum computing in one sentence.',
  response: 'Quantum computing uses qubits to process information...',
});

console.log(result.id);     // bytes32 — permanent on-chain ID
console.log(result.txHash); // basescan.org/tx/0x...
```

**Verify any attestation (permissionless, no key needed):**

```typescript
const client = new VerifiedAI({ network: 'base-mainnet' });

const isValid = await client.verify(attestationId);   // true | false
const record  = await client.getAttestation(attestationId);

console.log(record.modelId);   // 'gpt-4o'
console.log(record.attester);  // 0x... (who submitted)
console.log(record.valid);     // true
```

---

## Architecture

```
  Provider                    Base Mainnet                   Consumer
     │                             │                              │
     │  attest(model, in, out, π)  │                              │
     │────────────────────────────▶│  AttestationRegistry         │
     │                             │  └─ stores record (immutable)│
     │                             │                              │
     │  submitProof(id, πHash, pub)│                              │
     │────────────────────────────▶│  ZKVerifier                  │
     │                             │  └─ stores commitment        │
     │                             │                              │
     │                             │◀──────── verify(id) ─────────│
     │                             │          └─ true / false     │
     │                             │                              │
```

Full system design → [docs/architecture.md](docs/architecture.md)

---

## SDK Methods

| Method | Requires key | Description |
|---|---|---|
| `attest(params)` | ✅ | Submit inference attestation on-chain |
| `submitProof(params)` | ✅ | Link a ZK proof commitment to an attestation |
| `verify(id)` | ✗ | Returns `true` if attestation is valid |
| `getAttestation(id)` | ✗ | Fetch full attestation record |
| `getProof(id)` | ✗ | Fetch proof commitment |
| `listAttestations(addr)` | ✗ | All attestations from an address |
| `totalAttestations()` | ✗ | Registry total count |
| `watchAttestations(cb)` | ✗ | Real-time event listener |

Full API reference → [docs/sdk-reference.md](docs/sdk-reference.md)

---

## ZK Proof System

Verified AI uses **Groth16** on **BN254** — the most gas-efficient ZK proving system for EVM chains.

| Property | Value |
|---|---|
| Proof size | ~256 bytes |
| On-chain verification gas | ~250,000 |
| Cost per verification on Base | ~$0.005 |
| Proving time | 2–10 seconds |
| Trusted setup | Hermez Phase 2 ceremony (1,000+ participants) |

**What stays private:**

| On-chain (public) | Off-chain (private) |
|---|---|
| Model identifier | Model weights |
| Input hash | Raw prompt |
| Output hash | Raw response |
| Attester address | System prompt |
| Timestamp | User identity |

Deep dive → [docs/zk-proofs.md](docs/zk-proofs.md)

---

## Contract Interfaces

### AttestationRegistry

```solidity
/// @notice Submit an AI inference attestation
function attest(
    string  calldata modelId,
    bytes32          inputHash,    // keccak256(prompt)
    bytes32          outputHash,   // keccak256(response)
    bytes   calldata zkProof
) external returns (bytes32 attestationId);

/// @notice Check attestation validity (permissionless)
function verify(bytes32 id) external view returns (bool);

/// @notice Fetch full attestation record
function getAttestation(bytes32 id) external view returns (Attestation memory);
```

### ZKVerifier

```solidity
/// @notice Submit a ZK proof commitment
function submitProof(
    bytes32 attestationId,
    bytes32 proofHash,         // keccak256(Groth16 proof bytes)
    bytes32 publicInputsHash   // keccak256(modelHash ++ outputHash)
) external returns (bytes32 proofId);

/// @notice Check if an attestation has a valid proof
function verifyProof(bytes32 attestationId) external view returns (bool);
```

Full ABI and direct integration → [docs/contracts.md](docs/contracts.md)

---

## Roadmap

**v1 — Shipped**
- [x] `AttestationRegistry` — Base mainnet
- [x] `ZKVerifier` — Base mainnet
- [x] TypeScript SDK (`verified-ai-sdk`)
- [x] Comprehensive documentation

**v2 — In progress**
- [ ] Full Groth16 pairing check on-chain
- [ ] Lagrange DeepProve prover integration
- [ ] Base Sepolia testnet deployment
- [ ] Subgraph indexer

**v3 — Planned**
- [ ] Decentralized prover network
- [ ] `AgentCapabilityRegistry`
- [ ] `AIActCompliance` module
- [ ] Cross-chain bridge (Ethereum mainnet)
- [ ] REST API gateway

---

## Documentation

| Guide | What's inside |
|---|---|
| [Getting Started](docs/getting-started.md) | Install, wallet setup, first attestation |
| [Architecture](docs/architecture.md) | System diagram, data flow, trust model, gas table |
| [SDK Reference](docs/sdk-reference.md) | Full API, TypeScript types, error codes |
| [Contracts](docs/contracts.md) | ABI, events, ethers.js integration, security |
| [ZK Proofs](docs/zk-proofs.md) | Proof system, circuit design, privacy model |
| [Examples](docs/examples.md) | Next.js, batch, agent-to-agent, CLI, events |
| [FAQ](docs/faq.md) | Common questions answered |
| [Contributing](docs/contributing.md) | Setup, coding standards, PR process |

---

## Development

```bash
# Clone
git clone https://github.com/NeuroFade/verified-ai
cd verified-ai

# Install Foundry
curl -L https://foundry.paradigm.xyz | bash && foundryup

# Build contracts
forge build

# Run tests
forge test -vv

# Gas snapshot
forge snapshot
```

**Deploy to Base Sepolia (testnet):**

```bash
export PRIVATE_KEY=0x...

forge create src/AttestationRegistry.sol:AttestationRegistry \
  --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY

forge create src/ZKVerifier.sol:ZKVerifier \
  --rpc-url https://sepolia.base.org \
  --private-key $PRIVATE_KEY \
  --constructor-args <REGISTRY_ADDRESS>
```

Contributing guide → [docs/contributing.md](docs/contributing.md)

---

## License

MIT — see [LICENSE](LICENSE)

---

<div align="center">

Built on [Base](https://base.org) &nbsp;·&nbsp;
[AttestationRegistry](https://basescan.org/address/0x3dBF622ABC705d2Ec0E07EB0fCbb1AbFDe0281eb) &nbsp;·&nbsp;
[ZKVerifier](https://basescan.org/address/0xc303124d9276Ea7D3d75E94cE7fE5bd3DBec85d3) &nbsp;·&nbsp;
[MIT License](LICENSE)

</div>
