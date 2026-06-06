# Examples

Real-world usage patterns for Verified AI.

---

## 1. Basic attestation

The simplest possible flow — attest an inference, then verify it.

```typescript
import { VerifiedAI } from 'verified-ai-sdk';
import 'dotenv/config';

const client = new VerifiedAI({
  network: 'base-mainnet',
  privateKey: process.env.PRIVATE_KEY!,
});

async function main() {
  // Attest
  const result = await client.attest({
    model: 'gpt-4o',
    prompt: 'What is 2 + 2?',
    response: '4',
  });

  console.log('Attestation ID:', result.id);
  console.log('BaseScan:', `https://basescan.org/tx/${result.txHash}`);

  // Verify
  const valid = await client.verify(result.id);
  console.log('Valid:', valid); // true
}

main();
```

---

## 2. Verify before trusting

Pattern: a consumer verifies a third-party's attestation before using their AI output.

```typescript
async function verifyBeforeUsing(attestationId: string) {
  const client = new VerifiedAI({ network: 'base-mainnet' }); // read-only

  const isValid = await client.verify(attestationId);
  if (!isValid) throw new Error('Attestation invalid — cannot trust this output');

  const record = await client.getAttestation(attestationId);

  return {
    model: record.modelId,
    attestedAt: new Date(record.timestamp * 1000).toISOString(),
    attester: record.attester,
    valid: true,
  };
}
```

---

## 3. Audit trail for AI decisions

Record every AI decision with an on-chain audit trail.

```typescript
import { VerifiedAI } from 'verified-ai-sdk';

const client = new VerifiedAI({ network: 'base-mainnet', privateKey: process.env.PRIVATE_KEY! });

interface AIDecisionRecord {
  question: string;
  answer: string;
  attestationId: string;
  txHash: string;
  timestamp: string;
  verifiable: string; // BaseScan URL
}

async function recordDecision(question: string, answer: string): Promise<AIDecisionRecord> {
  const result = await client.attest({
    model: 'claude-3-5-sonnet',
    prompt: question,
    response: answer,
  });

  return {
    question,
    answer,
    attestationId: result.id,
    txHash: result.txHash,
    timestamp: new Date(result.timestamp * 1000).toISOString(),
    verifiable: `https://basescan.org/tx/${result.txHash}`,
  };
}

// Usage
const record = await recordDecision(
  'Should this loan application be approved?',
  'Approved — credit score 780, DTI ratio 28%, 5-year employment history'
);

console.log('Tamper-proof record:', JSON.stringify(record, null, 2));
```

---

## 4. Batch attestations

```typescript
const inferences = [
  { model: 'gpt-4o', prompt: 'Classify this email', response: 'Spam' },
  { model: 'gpt-4o', prompt: 'Sentiment: Great product!', response: 'Positive' },
  { model: 'claude-3-5-sonnet', prompt: 'Translate to French: Hello', response: 'Bonjour' },
];

// Parallel submission
const results = await Promise.all(
  inferences.map(inf => client.attest(inf))
);

console.log('Batch complete:');
results.forEach((r, i) => {
  console.log(`  [${i + 1}] ${r.id}`);
});
```

---

## 5. Real-time event monitoring

```typescript
const client = new VerifiedAI({ network: 'base-mainnet' });

console.log('Watching for new attestations...');

const unsubscribe = client.watchAttestations((attestation) => {
  console.log(`\n🔔 New attestation from ${attestation.attester}`);
  console.log(`   Model:  ${attestation.modelId}`);
  console.log(`   ID:     ${attestation.id}`);
  console.log(`   Valid:  ${attestation.valid}`);
});

// Run for 5 minutes then stop
setTimeout(() => {
  unsubscribe();
  console.log('Stopped watching.');
}, 5 * 60 * 1000);
```

---

## 6. Next.js API route

```typescript
// app/api/attest/route.ts
import { VerifiedAI } from 'verified-ai-sdk';
import { NextRequest, NextResponse } from 'next/server';

const client = new VerifiedAI({
  network: 'base-mainnet',
  privateKey: process.env.PRIVATE_KEY!,
});

export async function POST(req: NextRequest) {
  const { model, prompt, response } = await req.json();

  if (!model || !prompt || !response) {
    return NextResponse.json({ error: 'Missing required fields' }, { status: 400 });
  }

  try {
    const result = await client.attest({ model, prompt, response });
    return NextResponse.json({
      success: true,
      attestationId: result.id,
      txHash: result.txHash,
      explorer: `https://basescan.org/tx/${result.txHash}`,
    });
  } catch (err) {
    return NextResponse.json({ error: 'Attestation failed' }, { status: 500 });
  }
}

// GET /api/attest?id=0x...
export async function GET(req: NextRequest) {
  const id = req.nextUrl.searchParams.get('id');
  if (!id) return NextResponse.json({ error: 'Missing id param' }, { status: 400 });

  const [valid, record] = await Promise.all([
    client.verify(id),
    client.getAttestation(id),
  ]);

  return NextResponse.json({ valid, record });
}
```

---

## 7. Direct contract calls (no SDK)

```typescript
import { ethers } from 'ethers';

const REGISTRY = '0x3dBF622ABC705d2Ec0E07EB0fCbb1AbFDe0281eb';
const VERIFIER  = '0xc303124d9276Ea7D3d75E94cE7fE5bd3DBec85d3';

const provider = new ethers.JsonRpcProvider('https://mainnet.base.org');
const signer = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);

const registry = new ethers.Contract(REGISTRY, REGISTRY_ABI, signer);
const verifier  = new ethers.Contract(VERIFIER, VERIFIER_ABI, provider);

// Attest
const inputHash  = ethers.keccak256(ethers.toUtf8Bytes('prompt text'));
const outputHash = ethers.keccak256(ethers.toUtf8Bytes('response text'));
const tx = await registry.attest('gpt-4o', inputHash, outputHash, '0x');
const receipt = await tx.wait();
console.log('Attested at block:', receipt.blockNumber);

// Verify
const attId = receipt.logs[0].topics[1]; // attestationId from event
const valid = await verifier.verifyProof(attId);
console.log('Valid:', valid);
```

---

## 8. CLI tool

```bash
# Install
npm install -g verified-ai-sdk

# Attest
vai attest \
  --model gpt-4o \
  --prompt "What is the capital of Japan?" \
  --response "Tokyo" \
  --network base-mainnet

# Output:
# ✅ Attested!
#    ID:    0x3f4a...c9d2
#    TX:    https://basescan.org/tx/0xabcd...

# Verify
vai verify 0x3f4a...c9d2 --network base-mainnet

# Output:
# ✅ Valid (attested by 0x5E73... at 2025-01-15T14:23:00Z)
```

---

## 9. Agent-to-agent trust

Pattern: Agent A verifies Agent B's outputs before acting on them.

```typescript
import { VerifiedAI } from 'verified-ai-sdk';

class TrustingAgent {
  private client = new VerifiedAI({ network: 'base-mainnet' });

  async actOnResult(data: { answer: string; attestationId: string }) {
    // Verify before trusting
    const isVerified = await this.client.verify(data.attestationId);
    if (!isVerified) {
      throw new Error(`Cannot trust unverified AI output from agent`);
    }

    const record = await this.client.getAttestation(data.attestationId);
    console.log(`✅ Trusting output from model: ${record.modelId}`);
    console.log(`   Attested by: ${record.attester}`);

    // Now safe to act on data.answer
    return this.process(data.answer);
  }

  private process(answer: string) {
    // downstream processing
    return { processed: true, answer };
  }
}
```
