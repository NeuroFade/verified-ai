# SDK Reference

Complete API reference for `verified-ai-sdk`.

**Package:** `verified-ai-sdk`  
**Language:** TypeScript (types included)  
**Runtime:** Node.js 18+ / browser  
**Network:** Base Mainnet, Base Sepolia

---

## Installation

```bash
npm install verified-ai-sdk
```

---

## `new VerifiedAI(config)`

Creates a new client instance connected to the Verified AI contracts.

```typescript
import { VerifiedAI } from 'verified-ai-sdk';

const client = new VerifiedAI({
  network: 'base-mainnet',
  privateKey: process.env.PRIVATE_KEY, // required for write ops
});
```

### `VerifiedAIConfig`

```typescript
interface VerifiedAIConfig {
  /**
   * Target network.
   * 'base-mainnet' | 'base-sepolia'
   */
  network: Network;

  /**
   * Private key (hex, with or without 0x prefix).
   * Required for: attest(), submitProof()
   * Optional for: verify(), getAttestation(), getProof(), listAttestations(), totalAttestations()
   */
  privateKey?: string;

  /**
   * Custom RPC URL. Defaults to the network's public RPC.
   * base-mainnet default: https://mainnet.base.org
   * base-sepolia default: https://sepolia.base.org
   */
  rpcUrl?: string;
}

type Network = 'base-mainnet' | 'base-sepolia';
```

---

## Write Methods

These methods send transactions and require a `privateKey` in the config.

---

### `attest(params)`

Submit an AI inference attestation on-chain. Computes input/output hashes locally and writes them to `AttestationRegistry`.

```typescript
const result = await client.attest({
  model: 'gpt-4o',
  prompt: 'What is TypeScript?',
  response: 'TypeScript is a typed superset of JavaScript...',
});
```

**Parameters — `AttestParams`:**

```typescript
interface AttestParams {
  /**
   * Model identifier — free-form string.
   * Examples: 'gpt-4o', 'claude-3-5-sonnet', 'llama-3.3-70b'
   */
  model: string;

  /**
   * Raw input prompt (hashed locally, never sent to chain).
   */
  prompt: string;

  /**
   * Raw model response (hashed locally, never sent to chain).
   */
  response: string;

  /**
   * Optional metadata key/value pairs, stored as additional context.
   */
  metadata?: Record<string, string>;
}
```

**Returns — `AttestationResult`:**

```typescript
interface AttestationResult {
  /** Unique attestation ID — bytes32 hex string. */
  id: `0x${string}`;

  /** Transaction hash on Base. */
  txHash: `0x${string}`;

  /** Block number where attestation was mined. */
  blockNumber: number;

  /** Unix timestamp (seconds). */
  timestamp: number;

  /** Gas consumed by the transaction. */
  gasUsed: bigint;
}
```

---

### `submitProof(params)`

Submit a zero-knowledge proof commitment for an existing attestation. Writes to `ZKVerifier`.

```typescript
await client.submitProof({
  attestationId: result.id,
  proofHash: '0x...',         // keccak256 of the full Groth16 proof bytes
  publicInputsHash: '0x...', // keccak256(modelHash ++ outputHash)
});
```

**Parameters — `SubmitProofParams`:**

```typescript
interface SubmitProofParams {
  /** bytes32 ID returned by attest(). */
  attestationId: `0x${string}`;

  /** keccak256 hash of the ZK proof bytes. */
  proofHash: `0x${string}`;

  /** keccak256 of the concatenated public inputs. */
  publicInputsHash: `0x${string}`;
}
```

**Returns — `ProofResult`:**

```typescript
interface ProofResult {
  proofId: `0x${string}`;
  txHash: `0x${string}`;
  blockNumber: number;
  gasUsed: bigint;
}
```

---

## Read Methods

These methods only read from chain. No private key required.

---

### `verify(attestationId)`

Check if an attestation is valid.

```typescript
const isValid = await client.verify('0x3f4a...');
// Returns: true | false
```

| Parameter | Type | Description |
|---|---|---|
| `attestationId` | `string` | bytes32 hex attestation ID |

Returns `true` if the attestation exists and has a valid associated proof. Returns `false` if not found or invalidated.

---

### `getAttestation(id)`

Fetch the full attestation record.

```typescript
const att = await client.getAttestation('0x3f4a...');
```

**Returns — `Attestation`:**

```typescript
interface Attestation {
  /** bytes32 attestation ID. */
  id: `0x${string}`;

  /** Address that submitted the attestation. */
  attester: `0x${string}`;

  /** Model identifier. */
  modelId: string;

  /** keccak256(prompt). */
  inputHash: `0x${string}`;

  /** keccak256(response). */
  outputHash: `0x${string}`;

  /** keccak256(zkProof bytes). */
  proofHash: `0x${string}`;

  /** Block timestamp (seconds since epoch). */
  timestamp: number;

  /** Block number. */
  blockNumber: number;

  /** Whether the attestation has a verified proof. */
  valid: boolean;
}
```

---

### `getProof(attestationId)`

Fetch the ZK proof commitment linked to an attestation.

```typescript
const proof = await client.getProof('0x3f4a...');
```

**Returns — `ZKProof`:**

```typescript
interface ZKProof {
  /** bytes32 proof ID. */
  id: `0x${string}`;

  /** Linked attestation ID. */
  attestationId: `0x${string}`;

  /** keccak256 of the Groth16 proof bytes. */
  proofHash: `0x${string}`;

  /** keccak256 of the public inputs. */
  publicInputsHash: `0x${string}`;

  /** Address that submitted the proof. */
  prover: `0x${string}`;

  /** Submission timestamp (seconds). */
  timestamp: number;

  /** Whether proof is valid. */
  valid: boolean;
}
```

---

### `listAttestations(address)`

Fetch all attestation IDs submitted by an address.

```typescript
const ids = await client.listAttestations('0xabc...');
// Returns: `0x${string}`[]
```

Fetch full records:

```typescript
const ids = await client.listAttestations('0xabc...');
const records = await Promise.all(ids.map(id => client.getAttestation(id)));
```

---

### `totalAttestations()`

Total number of attestations in the registry.

```typescript
const total = await client.totalAttestations();
console.log(`Total: ${total}`); // bigint
```

---

### `watchAttestations(callback)`

Subscribe to new attestations in real-time via event listener.

```typescript
const unsubscribe = client.watchAttestations((attestation: Attestation) => {
  console.log('New attestation:', attestation.id);
  console.log('Model:', attestation.modelId);
  console.log('From:', attestation.attester);
});

// Stop listening
unsubscribe();
```

---

## Utilities

### `CONTRACTS`

Contract addresses by network:

```typescript
import { CONTRACTS } from 'verified-ai-sdk';

CONTRACTS['base-mainnet'].registry
// '0x3dBF622ABC705d2Ec0E07EB0fCbb1AbFDe0281eb'

CONTRACTS['base-mainnet'].verifier
// '0xc303124d9276Ea7D3d75E94cE7fE5bd3DBec85d3'
```

### `hashPrompt(text)` / `hashResponse(text)`

Compute the keccak256 hash the SDK uses internally:

```typescript
import { hashPrompt, hashResponse } from 'verified-ai-sdk';

const inputHash  = hashPrompt('What is TypeScript?');
const outputHash = hashResponse('TypeScript is a typed superset...');
// Returns: `0x${string}` (bytes32 hex)
```

---

## Error handling

```typescript
import { VerifiedAIError, ErrorCode } from 'verified-ai-sdk';

try {
  const result = await client.attest({ model, prompt, response });
} catch (err) {
  if (err instanceof VerifiedAIError) {
    switch (err.code) {
      case ErrorCode.INSUFFICIENT_GAS:
        console.error('Need more ETH on Base for gas');
        break;
      case ErrorCode.INVALID_PROOF:
        console.error('ZK proof validation failed');
        break;
      case ErrorCode.ATTESTATION_NOT_FOUND:
        console.error('Attestation ID not in registry');
        break;
      case ErrorCode.INVALID_NETWORK:
        console.error('Unknown network identifier');
        break;
      case ErrorCode.MISSING_PRIVATE_KEY:
        console.error('privateKey required for write operations');
        break;
      default:
        console.error('Unexpected error:', err.message);
    }
  }
}
```

### `ErrorCode` enum

```typescript
enum ErrorCode {
  INSUFFICIENT_GAS      = 'INSUFFICIENT_GAS',
  INVALID_PROOF         = 'INVALID_PROOF',
  ATTESTATION_NOT_FOUND = 'ATTESTATION_NOT_FOUND',
  PROOF_NOT_FOUND       = 'PROOF_NOT_FOUND',
  INVALID_NETWORK       = 'INVALID_NETWORK',
  MISSING_PRIVATE_KEY   = 'MISSING_PRIVATE_KEY',
  RPC_ERROR             = 'RPC_ERROR',
  CONTRACT_REVERT       = 'CONTRACT_REVERT',
}
```

---

## All types

```typescript
export type Network = 'base-mainnet' | 'base-sepolia';

export interface VerifiedAIConfig {
  network: Network;
  privateKey?: string;
  rpcUrl?: string;
}

export interface AttestParams {
  model: string;
  prompt: string;
  response: string;
  metadata?: Record<string, string>;
}

export interface SubmitProofParams {
  attestationId: `0x${string}`;
  proofHash: `0x${string}`;
  publicInputsHash: `0x${string}`;
}

export interface AttestationResult {
  id: `0x${string}`;
  txHash: `0x${string}`;
  blockNumber: number;
  timestamp: number;
  gasUsed: bigint;
}

export interface ProofResult {
  proofId: `0x${string}`;
  txHash: `0x${string}`;
  blockNumber: number;
  gasUsed: bigint;
}

export interface Attestation {
  id: `0x${string}`;
  attester: `0x${string}`;
  modelId: string;
  inputHash: `0x${string}`;
  outputHash: `0x${string}`;
  proofHash: `0x${string}`;
  timestamp: number;
  blockNumber: number;
  valid: boolean;
}

export interface ZKProof {
  id: `0x${string}`;
  attestationId: `0x${string}`;
  proofHash: `0x${string}`;
  publicInputsHash: `0x${string}`;
  prover: `0x${string}`;
  timestamp: number;
  valid: boolean;
}
```
