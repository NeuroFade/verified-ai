# SDK Reference

Full API reference for the `verified-ai-sdk` TypeScript package.

---

## Installation

```bash
npm install verified-ai-sdk
```

---

## `VerifiedAI` Class

### Constructor

```typescript
new VerifiedAI(config: ClientConfig)
```

#### `ClientConfig`

```typescript
interface ClientConfig {
  network: 'base-mainnet' | 'base-sepolia';
  privateKey: string;
  rpcUrl?: string;              // Custom RPC (optional)
  registryAddress?: string;    // Override contract address (optional)
  verifierAddress?: string;    // Override verifier address (optional)
  timeout?: number;            // Request timeout in ms (default: 30000)
}
```

---

## Methods

### `attest(options)`

Submit a new attestation for an AI inference.

```typescript
async attest(options: AttestOptions): Promise<Attestation>
```

#### `AttestOptions`

```typescript
interface AttestOptions {
  model: string;          // Model identifier (e.g. 'gpt-4o', 'claude-3-5-sonnet')
  prompt: string;         // Input to the model
  response: string;       // Model's output
  metadata?: Record<string, unknown>;  // Optional structured metadata
  gasLimit?: bigint;      // Override gas limit
}
```

#### Returns: `Attestation`

```typescript
interface Attestation {
  id: string;           // bytes32 attestation ID (hex)
  txHash: string;       // Transaction hash
  blockNumber: number;  // Block where tx was mined
  timestamp: number;    // Unix timestamp
  attester: string;     // Address that submitted
  modelId: string;      // Model identifier
  inputHash: string;    // keccak256 of prompt
  outputHash: string;   // keccak256 of response
  proofHash: string;    // ZK proof hash
  valid: boolean;       // Proof validity
}
```

#### Example

```typescript
const result = await client.attest({
  model: 'gpt-4o',
  prompt: 'What is 2+2?',
  response: '4',
  metadata: { temperature: 0.7, tokens: 12 }
});

console.log(result.id);      // 0x3f4a...c9d2
console.log(result.valid);   // true
```

---

### `verify(attestationId)`

Check if an attestation is valid.

```typescript
async verify(attestationId: string): Promise<boolean>
```

#### Example

```typescript
const valid = await client.verify('0x3f4a...c9d2');
// → true
```

---

### `getAttestation(id)`

Retrieve the full attestation record.

```typescript
async getAttestation(id: string): Promise<Attestation>
```

#### Example

```typescript
const record = await client.getAttestation('0x3f4a...c9d2');
console.log(record.timestamp);  // 1717689600
console.log(record.modelId);    // 'gpt-4o'
```

---

### `listAttestations(filter?)`

Query attestations with optional filters.

```typescript
async listAttestations(filter?: AttestationFilter): Promise<Attestation[]>
```

#### `AttestationFilter`

```typescript
interface AttestationFilter {
  attester?: string;    // Filter by attester address
  model?: string;       // Filter by model ID
  from?: number;        // Unix timestamp start
  to?: number;          // Unix timestamp end
  limit?: number;       // Max results (default: 100)
  offset?: number;      // Pagination offset
}
```

#### Example

```typescript
const attestations = await client.listAttestations({
  model: 'gpt-4o',
  limit: 20,
});
```

---

### `watchAttestations(callback, filter?)`

Subscribe to new attestation events in real-time.

```typescript
watchAttestations(
  callback: (attestation: Attestation) => void,
  filter?: AttestationFilter
): Unsubscribe
```

#### Example

```typescript
const unsubscribe = client.watchAttestations((att) => {
  console.log('New attestation:', att.id);
}, { model: 'gpt-4o' });

// Later:
unsubscribe();
```

---

## Errors

All methods throw typed errors:

```typescript
import { VerifiedAIError } from 'verified-ai-sdk';

try {
  await client.verify('0xinvalid');
} catch (e) {
  if (e instanceof VerifiedAIError) {
    console.log(e.code);    // 'INVALID_ID' | 'NOT_FOUND' | 'NETWORK_ERROR' | ...
    console.log(e.message); // Human-readable message
  }
}
```

### Error Codes

| Code | Description |
|---|---|
| `INVALID_ID` | Attestation ID format invalid |
| `NOT_FOUND` | Attestation not found on-chain |
| `PROOF_INVALID` | ZK proof failed verification |
| `NETWORK_ERROR` | RPC / network failure |
| `TX_FAILED` | Transaction reverted |
| `TIMEOUT` | Request exceeded timeout |

---

## TypeScript Types

```typescript
import type {
  ClientConfig,
  AttestOptions,
  Attestation,
  AttestationFilter,
  VerifiedAIError,
} from 'verified-ai-sdk';
```
