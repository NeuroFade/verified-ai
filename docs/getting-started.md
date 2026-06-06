# Getting Started

Welcome to Verified AI. This guide will get you from zero to your first on-chain attestation in under 10 minutes.

---

## Prerequisites

| Requirement | Version | Notes |
|---|---|---|
| Node.js | 18+ | LTS recommended |
| npm / yarn | any | Package manager |
| Base wallet | — | With testnet ETH on Base Sepolia |
| Private key | — | Never commit to git |

---

## Step 1 — Install

```bash
npm install verified-ai-sdk
```

Or with yarn:
```bash
yarn add verified-ai-sdk
```

---

## Step 2 — Configure

Create a `.env` file:

```bash
PRIVATE_KEY=0xYourPrivateKeyHere
RPC_URL=https://mainnet.base.org   # or https://sepolia.base.org for testnet
```

> ⚠️ Never share or commit your private key.

---

## Step 3 — Initialize Client

```typescript
import { VerifiedAI } from 'verified-ai-sdk';
import * as dotenv from 'dotenv';
dotenv.config();

const client = new VerifiedAI({
  network: 'base-sepolia',        // Start on testnet
  privateKey: process.env.PRIVATE_KEY!,
});
```

---

## Step 4 — Create Your First Attestation

```typescript
const attestation = await client.attest({
  model: 'gpt-4o',
  prompt: 'Summarize the Ethereum whitepaper',
  response: 'Ethereum is a decentralized platform...',
});

console.log('✅ Attestation created!');
console.log('ID:', attestation.id);
console.log('Tx:', `https://sepolia.basescan.org/tx/${attestation.txHash}`);
```

---

## Step 5 — Verify It

```typescript
const isValid = await client.verify(attestation.id);
console.log('Valid:', isValid); // → true
```

---

## Next Steps

- Read the [SDK Reference](./sdk-reference.md) for full API docs
- Check [Contract Interface](./contracts.md) for on-chain integration
- See [Examples](./examples.md) for real-world patterns
- Learn about [ZK Proofs](./zk-proofs.md) in the protocol
