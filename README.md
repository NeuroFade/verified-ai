# ![Verified AI](./logo.jpg)

# Verified AI

> **On-chain attestation layer for AI inference. Prove your model ran.**

[![License: MIT](https://img.shields.io/badge/License-MIT-white.svg)](LICENSE)
[![Built on Base](https://img.shields.io/badge/Built%20on-Base-0052FF.svg)](https://base.org)
[![Solidity](https://img.shields.io/badge/Solidity-^0.8.20-gray.svg)](https://soliditylang.org)
[![TypeScript](https://img.shields.io/badge/TypeScript-5.0-3178C6.svg)](https://www.typescriptlang.org)

---

## What is Verified AI?

Verified AI is a decentralized attestation protocol that enables any AI inference to be cryptographically verified on-chain. Using a combination of ZK proofs and smart contract attestations, it creates an immutable trust layer between AI models and the applications that consume them.

**Core problem:** AI outputs are inherently unverifiable. When your app calls an LLM, you have no proof of:
- Which model actually ran
- Whether the output was tampered with
- That the inference happened at all

**Verified AI solves this** by anchoring every inference to a verifiable on-chain record.

---

## Architecture

```
┌──────────────────┐     ┌─────────────────┐     ┌──────────────────────┐
│   AI Inference   │────▶│   ZK Prover     │────▶│  AttestationRegistry │
│   (any model)    │     │  (off-chain)    │     │   (Base mainnet)     │
└──────────────────┘     └─────────────────┘     └──────────────────────┘
         │                       │                          │
         │                       ▼                          ▼
         │               ┌─────────────────┐     ┌──────────────────────┐
         └──────────────▶│   ZKVerifier    │────▶│   On-chain Record    │
                         │  (smart contract│     │  (immutable, public) │
                         └─────────────────┘     └──────────────────────┘
```

1. **AI Model** runs inference and produces output + execution metadata
2. **ZK Prover** generates a zero-knowledge proof of the inference
3. **ZKVerifier** contract validates the proof on-chain
4. **AttestationRegistry** stores the immutable attestation record
5. Any party can verify the attestation using the SDK

---

## Contracts

| Contract | Address (Base) | Description |
|---|---|---|
| `AttestationRegistry` | [`0x3dBF622ABC705d2Ec0E07EB0fCbb1AbFDe0281eb`](https://basescan.org/address/0x3dBF622ABC705d2Ec0E07EB0fCbb1AbFDe0281eb) | Stores all attestation records |
| `ZKVerifier` | [`0xc303124d9276Ea7D3d75E94cE7fE5bd3DBec85d3`](https://basescan.org/address/0xc303124d9276Ea7D3d75E94cE7fE5bd3DBec85d3) | Validates ZK proofs on-chain |

View on BaseScan: [AttestationRegistry](https://basescan.org/address/0x3dBF622ABC705d2Ec0E07EB0fCbb1AbFDe0281eb) · [ZKVerifier](https://basescan.org/address/0xc303124d9276Ea7D3d75E94cE7fE5bd3DBec85d3)

---

## Quick Start

### Prerequisites

- Node.js 18+
- A Base-compatible wallet
- `PRIVATE_KEY` in environment

### Install

```bash
npm install verified-ai-sdk
```

### Basic Usage

```typescript
import { VerifiedAI } from 'verified-ai-sdk';

const client = new VerifiedAI({
  network: 'base-mainnet',
  privateKey: process.env.PRIVATE_KEY,
});

// 1. Run inference and attest
const attestation = await client.attest({
  model: 'gpt-4o',
  prompt: 'What is the capital of France?',
  response: 'Paris',
});

console.log('Attestation ID:', attestation.id);
// → 0x3f4a...c9d2

// 2. Verify any attestation
const isValid = await client.verify(attestation.id);
console.log('Valid:', isValid); // → true
```

---

## SDK Reference

### `VerifiedAI`

Main client class.

```typescript
const client = new VerifiedAI(config: ClientConfig);
```

#### `ClientConfig`

| Field | Type | Description |
|---|---|---|
| `network` | `'base-mainnet' \| 'base-sepolia'` | Target network |
| `privateKey` | `string` | Wallet private key for signing |
| `rpcUrl` | `string` (optional) | Custom RPC endpoint |

---

### `client.attest(options)`

Submit a new attestation for an AI inference.

```typescript
const attestation = await client.attest({
  model: string,      // Model identifier
  prompt: string,     // Input prompt
  response: string,   // Model output
  metadata?: object,  // Optional extra data
});
```

**Returns:** `Attestation` object

```typescript
{
  id: string,           // Unique attestation ID (bytes32)
  txHash: string,       // Transaction hash
  blockNumber: number,  // Block where attestation landed
  timestamp: number,    // Unix timestamp
  valid: boolean,       // ZK proof validity
}
```

---

### `client.verify(attestationId)`

Verify an existing attestation.

```typescript
const isValid = await client.verify('0x3f4a...c9d2');
// → true | false
```

---

### `client.getAttestation(id)`

Retrieve full attestation record.

```typescript
const record = await client.getAttestation('0x3f4a...c9d2');
```

**Returns:** Full `AttestationRecord` with all metadata.

---

### `client.listAttestations(filter?)`

List attestations with optional filters.

```typescript
const attestations = await client.listAttestations({
  model: 'gpt-4o',
  from: '0xYourAddress',
  limit: 50,
});
```

---

## Smart Contract Interface

### `AttestationRegistry.sol`

```solidity
interface IAttestationRegistry {
    struct Attestation {
        bytes32 id;
        address attester;
        string modelId;
        bytes32 inputHash;
        bytes32 outputHash;
        bytes32 proofHash;
        uint256 timestamp;
        bool valid;
    }

    function attest(
        string calldata modelId,
        bytes32 inputHash,
        bytes32 outputHash,
        bytes calldata zkProof
    ) external returns (bytes32 attestationId);

    function getAttestation(bytes32 id)
        external view returns (Attestation memory);

    function verify(bytes32 id)
        external view returns (bool);

    event AttestationCreated(
        bytes32 indexed id,
        address indexed attester,
        string modelId,
        uint256 timestamp
    );
}
```

---

### `ZKVerifier.sol`

```solidity
interface IZKVerifier {
    function verifyProof(
        bytes calldata proof,
        bytes32 inputHash,
        bytes32 outputHash
    ) external view returns (bool);
}
```

---

## Development

### Clone & Setup

```bash
git clone https://github.com/NeuroFade/verified-ai.git
cd verified-ai
npm install
```

### Environment

```bash
cp .env.example .env
# Set PRIVATE_KEY, RPC_URL
```

### Deploy Contracts

```bash
npx hardhat deploy --network base-sepolia
```

### Run Tests

```bash
npx hardhat test
```

### Build SDK

```bash
npm run build
```

---

## Roadmap

- [x] AttestationRegistry contract (Base mainnet)
- [x] ZKVerifier contract
- [x] TypeScript SDK
- [x] Landing page + documentation
- [ ] IPFS proof pinning
- [ ] Multi-chain support (Ethereum, Optimism, Arbitrum)
- [ ] Model registry — whitelist trusted model IDs
- [ ] Reputation scoring for AI attesters
- [ ] REST API gateway
- [ ] Dashboard UI

---

## Contributing

PRs welcome. Please open an issue first for major changes.

1. Fork the repo
2. Create feature branch: `git checkout -b feat/your-feature`
3. Commit: `git commit -m 'feat: add your feature'`
4. Push: `git push origin feat/your-feature`
5. Open a Pull Request

---

## License

MIT © [NeuroFade](https://github.com/NeuroFade)

---

<div align="center">
  <sub>Built on Base · Powered by ZK Proofs · Verified on-chain</sub>
</div>
