# Getting Started

Get your first on-chain attestation in under 5 minutes.

---

## What you'll need

| Requirement | Details |
|---|---|
| Node.js | v18 or higher |
| ETH on Base | ~0.001 ETH (~$2.50) for gas |
| A private key | Any EVM-compatible wallet |

Don't have Base ETH yet? [Bridge from Ethereum →](https://bridge.base.org) or buy on [Coinbase](https://coinbase.com).

---

## Step 1 — Install the SDK

```bash
npm install verified-ai-sdk
# or
yarn add verified-ai-sdk
# or
pnpm add verified-ai-sdk
```

---

## Step 2 — Set up your environment

Create a `.env` file in your project root. **Never commit this file.**

```bash
# .env
PRIVATE_KEY=0xYOUR_PRIVATE_KEY_HERE
BASE_RPC_URL=https://mainnet.base.org
```

Add to `.gitignore`:

```bash
echo ".env" >> .gitignore
```

---

## Step 3 — Initialize the client

```typescript
import 'dotenv/config';
import { VerifiedAI } from 'verified-ai-sdk';

const client = new VerifiedAI({
  network: 'base-mainnet',
  privateKey: process.env.PRIVATE_KEY!,
});
```

For **read-only** use (just verifying attestations, no signing needed):

```typescript
// No privateKey required
const client = new VerifiedAI({ network: 'base-mainnet' });
```

---

## Step 4 — Submit your first attestation

```typescript
const result = await client.attest({
  model: 'gpt-4o',
  prompt: 'What is the capital of Japan?',
  response: 'The capital of Japan is Tokyo.',
});

console.log('✅ Attestation created!');
console.log('  ID:     ', result.id);
console.log('  TX:     ', `https://basescan.org/tx/${result.txHash}`);
console.log('  Block:  ', result.blockNumber);
```

The `id` is a `bytes32` hex string — it's your permanent, on-chain attestation reference.

---

## Step 5 — Verify it

```typescript
// Check validity
const isValid = await client.verify(result.id);
console.log('Valid:', isValid); // true

// Fetch the full record
const record = await client.getAttestation(result.id);
console.log('Model:     ', record.modelId);       // 'gpt-4o'
console.log('Attester:  ', record.attester);      // your wallet address
console.log('Timestamp: ', new Date(record.timestamp * 1000).toISOString());
console.log('Valid:     ', record.valid);          // true
```

---

## Step 6 — View on BaseScan

Click the BaseScan link from your output to see the transaction live:

- **AttestationRegistry:** [basescan.org/address/0x3dBF622A...](https://basescan.org/address/0x3dBF622ABC705d2Ec0E07EB0fCbb1AbFDe0281eb)
- **ZKVerifier:** [basescan.org/address/0xc303124d...](https://basescan.org/address/0xc303124d9276Ea7D3d75E94cE7fE5bd3DBec85d3)

On BaseScan → **Read Contract** → call `getAttestation(bytes32)` with your ID → confirm `valid: true`.

---

## Full working example

```typescript
// attest.ts
import 'dotenv/config';
import { VerifiedAI } from 'verified-ai-sdk';

async function main() {
  const client = new VerifiedAI({
    network: 'base-mainnet',
    privateKey: process.env.PRIVATE_KEY!,
  });

  // 1. Attest
  console.log('Submitting attestation...');
  const result = await client.attest({
    model: 'gpt-4o',
    prompt: 'Summarize the French Revolution in one sentence.',
    response:
      'The French Revolution was a period of radical political and societal change ' +
      'that began with the Estates General of 1789 and ended with Napoleon\'s rise in 1799.',
  });

  console.log(`\n✅ Attested successfully!`);
  console.log(`   ID:      ${result.id}`);
  console.log(`   TX:      https://basescan.org/tx/${result.txHash}`);
  console.log(`   Gas:     ${result.gasUsed.toString()}`);

  // 2. Verify
  const isValid = await client.verify(result.id);
  console.log(`\n🔍 Verification: ${isValid ? '✅ Valid' : '❌ Invalid'}`);

  // 3. Fetch record
  const att = await client.getAttestation(result.id);
  console.log(`\n📋 Attestation record:`);
  console.log(`   Model:     ${att.modelId}`);
  console.log(`   Attester:  ${att.attester}`);
  console.log(`   Timestamp: ${new Date(att.timestamp * 1000).toISOString()}`);
}

main().catch(console.error);
```

Run it:

```bash
npx ts-node attest.ts
```

---

## Using testnet (Base Sepolia)

For development, use Base Sepolia — free ETH, no real money at risk.

Get Sepolia ETH from the [Coinbase faucet](https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet).

```typescript
const client = new VerifiedAI({
  network: 'base-sepolia',  // ← switch here
  privateKey: process.env.PRIVATE_KEY!,
});
```

---

## Common errors

| Error | Cause | Fix |
|---|---|---|
| `insufficient funds` | Not enough ETH for gas | Add ETH to your wallet on Base |
| `invalid private key` | Malformed key | Check key format — must start with `0x` and be 32 bytes |
| `network not found` | Wrong network string | Use `'base-mainnet'` or `'base-sepolia'` exactly |
| `attestation not found` | Invalid ID | Double-check the `bytes32` ID format |

---

## Next steps

| Guide | Description |
|---|---|
| [Architecture](./architecture.md) | Understand the full system design |
| [SDK Reference](./sdk-reference.md) | Every method, type, and option |
| [Examples](./examples.md) | Next.js API, batch attestation, real-time events |
| [Contracts](./contracts.md) | Direct contract interaction, ABI reference |
| [ZK Proofs](./zk-proofs.md) | How the proof system works |
