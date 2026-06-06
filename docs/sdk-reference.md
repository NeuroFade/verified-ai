# SDK Reference

Full API reference for `verified-ai-sdk`.

---

## Installation

```bash
npm install verified-ai-sdk
```

---

## `new VerifiedAI(config)`

Creates a new client instance.

```typescript
const client = new VerifiedAI({
  network: 'base-mainnet',   // 'base-mainnet' | 'base-sepolia'
  privateKey: '0x...',       // optional; required for write operations
  rpcUrl: 'https://...',     // optional; overrides default RPC
});
```

### Config

| Field | Type | Required | Default |
|---|---|---|---|
| `network` | `'base-mainnet' \| 'base-sepolia'` | ✅ | — |
| `privateKey` | `string` | ✗ | — |
| `rpcUrl` | `string` | ✗ | Network default |

---

## Write Methods

### `attest(params)`

Submit an AI inference attestation on-chain.

```typescript
const result = await client.attest({
  model: 'gpt-4o',
  prompt: 'Your prompt',
  response: 'Model response',
});
```

**Params:**

| Field | Type | Description |
|---|---|---|
| `model` | `string` | Model identifier (e.g. `'gpt-4o'`, `'claude-3-5-sonnet'`) |
| `prompt` | `string` | Raw input prompt |
| `response` | `string` | Raw model output |
| `metadata?` | `object` | Optional key/value metadata |

**Returns: `AttestationResult`**

```typescript
interface AttestationResult {
  id: string;          // bytes32 attestation ID (hex)
  txHash: string;      // transaction hash
  blockNumber: number; // block where attestation was mined
  timestamp: number;   // unix timestamp
  gasUsed: bigint;     // gas consumed
}
```

---

### `submitProof(params)`

Submit a ZK proof commitment for an existing attestation.

```typescript
await client.submitProof({
  attestationId: result.id,
  proofHash: '0x...',       // keccak256 of the full proof bytes
  publicInputsHash: '0x...',// keccak256(modelHash ++ outputHash)
});
```

**Params:**

| Field | Type | Description |
|---|---|---|
| `attestationId` | `string` | ID from `attest()` |
| `proofHash` | `string` | keccak256 hash of proof bytes |
| `publicInputsHash` | `string` | keccak256 of public inputs |

---

## Read Methods

### `verify(attestationId)`

Check if an attestation is valid.

```typescript
const isValid = await client.verify('0x3f4a...');
// Returns: true | false
```

---

### `getAttestation(id)`

Fetch a full attestation record.

```typescript
const att = await client.getAttestation('0x3f4a...');
```

**Returns: `Attestation`**

```typescript
interface Attestation {
  id: string;
  attester: string;       // address that submitted
  modelId: string;        // model identifier
  inputHash: string;      // keccak256(prompt)
  outputHash: string;     // keccak256(response)
  proofHash: string;      // keccak256(zkProof)
  timestamp: number;      // unix timestamp
  blockNumber: number;
  valid: boolean;
}
```

---

### `getProof(attestationId)`

Fetch a ZK proof record.

```typescript
const proof = await client.getProof(attestationId);
```

**Returns: `ZKProof`**

```typescript
interface ZKProof {
  id: string;              // proof ID
  attestationId: string;
  proofHash: string;
  publicInputsHash: string;
  prover: string;          // address that submitted proof
  timestamp: number;
  valid: boolean;
}
```

---

### `listAttestations(address)`

Fetch all attestations submitted by an address.

```typescript
const attestations = await client.listAttestations('0xabc...');
// Returns: Attestation[]
```

---

### `watchAttestations(callback)`

Listen for new attestations in real-time.

```typescript
const unsubscribe = client.watchAttestations((attestation) => {
  console.log('New attestation:', attestation.id);
  console.log('Model:', attestation.modelId);
});

// Stop listening
unsubscribe();
```

---

### `totalAttestations()`

Get total attestation count from the registry.

```typescript
const total = await client.totalAttestations();
console.log('Total:', total.toString());
```

---

## Types

```typescript
type Network = 'base-mainnet' | 'base-sepolia';

interface VerifiedAIConfig {
  network: Network;
  privateKey?: string;
  rpcUrl?: string;
}

interface AttestParams {
  model: string;
  prompt: string;
  response: string;
  metadata?: Record<string, string>;
}

interface AttestationResult {
  id: string;
  txHash: string;
  blockNumber: number;
  timestamp: number;
  gasUsed: bigint;
}

interface Attestation {
  id: string;
  attester: string;
  modelId: string;
  inputHash: string;
  outputHash: string;
  proofHash: string;
  timestamp: number;
  blockNumber: number;
  valid: boolean;
}

interface ZKProof {
  id: string;
  attestationId: string;
  proofHash: string;
  publicInputsHash: string;
  prover: string;
  timestamp: number;
  valid: boolean;
}
```

---

## Contract Addresses

```typescript
import { CONTRACTS } from 'verified-ai-sdk';

CONTRACTS['base-mainnet'].registry
// '0x3dBF622ABC705d2Ec0E07EB0fCbb1AbFDe0281eb'

CONTRACTS['base-mainnet'].verifier
// '0xc303124d9276Ea7D3d75E94cE7fE5bd3DBec85d3'
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
        console.error('Not enough ETH for gas');
        break;
      case ErrorCode.INVALID_PROOF:
        console.error('ZK proof validation failed');
        break;
      case ErrorCode.ATTESTATION_NOT_FOUND:
        console.error('Attestation ID does not exist');
        break;
    }
  }
}
```
