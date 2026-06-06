# Getting Started

Get your first on-chain attestation in under 5 minutes.

---

## Prerequisites

- Node.js 18+
- A Base mainnet RPC endpoint (default: `https://mainnet.base.org`)
- A funded wallet with ~0.001 ETH on Base (for gas)

---

## 1. Install the SDK

```bash
npm install verified-ai-sdk
# or
yarn add verified-ai-sdk
# or
pnpm add verified-ai-sdk
```

---

## 2. Initialize the client

```typescript
import { VerifiedAI } from 'verified-ai-sdk';

const client = new VerifiedAI({
  network: 'base-mainnet',
  privateKey: process.env.PRIVATE_KEY!, // needed for write operations
});
```

For read-only use (just verifying), omit `privateKey`:

```typescript
const client = new VerifiedAI({ network: 'base-mainnet' });
const isValid = await client.verify('0x3f4a...');
```

---

## 3. Submit your first attestation

```typescript
const result = await client.attest({
  model: 'gpt-4o',
  prompt: 'What is the capital of France?',
  response: 'The capital of France is Paris.',
});

console.log('✅ Attested!');
console.log('  ID:      ', result.id);
console.log('  TX:      ', `https://basescan.org/tx/${result.txHash}`);
console.log('  Mined:   ', result.blockNumber);
```

---

## 4. Verify it

```typescript
const isValid = await client.verify(result.id);
console.log('Valid:', isValid); // true

const record = await client.getAttestation(result.id);
console.log('Model:     ', record.modelId);
console.log('Timestamp: ', new Date(record.timestamp * 1000).toISOString());
console.log('Valid:     ', record.valid);
```

---

## 5. View on BaseScan

Every attestation is publicly queryable:

- [AttestationRegistry on BaseScan](https://basescan.org/address/0x3dBF622ABC705d2Ec0E07EB0fCbb1AbFDe0281eb)
- [ZKVerifier on BaseScan](https://basescan.org/address/0xc303124d9276Ea7D3d75E94cE7fE5bd3DBec85d3)

---

## Environment setup

Create a `.env` file:

```env
PRIVATE_KEY=0x...
BASE_RPC_URL=https://mainnet.base.org
```

Load with `dotenv`:

```typescript
import 'dotenv/config';
import { VerifiedAI } from 'verified-ai-sdk';

const client = new VerifiedAI({
  network: 'base-mainnet',
  privateKey: process.env.PRIVATE_KEY!,
  rpcUrl: process.env.BASE_RPC_URL,
});
```

---

## Testnet (Base Sepolia)

For development, use Base Sepolia — get free ETH from the [Coinbase faucet](https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet):

```typescript
const client = new VerifiedAI({
  network: 'base-sepolia',
  privateKey: process.env.PRIVATE_KEY!,
});
```

---

## Next steps

- [SDK Reference](./sdk-reference.md) — full method documentation
- [Examples](./examples.md) — Next.js, CLI, batch patterns
- [ZK Proofs](./zk-proofs.md) — how the proof system works
- [Contracts](./contracts.md) — ABI and direct integration
