# Examples

Real-world usage patterns for Verified AI.

---

## Basic Attestation

```typescript
import { VerifiedAI } from 'verified-ai-sdk';

const client = new VerifiedAI({
  network: 'base-mainnet',
  privateKey: process.env.PRIVATE_KEY!,
});

const result = await client.attest({
  model: 'gpt-4o',
  prompt: 'Explain quantum computing in one sentence.',
  response: 'Quantum computing uses quantum mechanical phenomena...',
});

console.log('Attestation ID:', result.id);
console.log('BaseScan:', `https://basescan.org/tx/${result.txHash}`);
```

---

## Verify Before Using Output

Pattern: verify an attestation from a third-party before trusting their AI output.

```typescript
async function trustedAIResponse(attestationId: string): Promise<boolean> {
  const client = new VerifiedAI({
    network: 'base-mainnet',
    privateKey: process.env.PRIVATE_KEY!,
  });

  const isValid = await client.verify(attestationId);

  if (!isValid) {
    throw new Error('Attestation invalid — AI output cannot be trusted');
  }

  const record = await client.getAttestation(attestationId);
  console.log('Verified output from model:', record.modelId);
  console.log('Attested at block:', record.blockNumber);

  return true;
}
```

---

## Batch Attestations

```typescript
const prompts = [
  { model: 'gpt-4o', prompt: 'Question 1', response: 'Answer 1' },
  { model: 'claude-3-5-sonnet', prompt: 'Question 2', response: 'Answer 2' },
  { model: 'gpt-4o', prompt: 'Question 3', response: 'Answer 3' },
];

const attestations = await Promise.all(
  prompts.map(p => client.attest(p))
);

console.log('All attestation IDs:');
attestations.forEach(a => console.log(a.id));
```

---

## Event Listener

Real-time monitoring of new attestations:

```typescript
const unsubscribe = client.watchAttestations((attestation) => {
  console.log(`New ${attestation.modelId} attestation:`, attestation.id);
  console.log(`Attester: ${attestation.attester}`);
  console.log(`Valid: ${attestation.valid}`);
});

// Stop listening after 60 seconds
setTimeout(() => unsubscribe(), 60_000);
```

---

## Audit Trail

Build a complete audit trail of AI decisions:

```typescript
interface AIDecision {
  decision: string;
  reason: string;
  attestationId: string;
  timestamp: number;
}

async function attestedDecision(
  prompt: string,
  model: string,
  aiResponse: string
): Promise<AIDecision> {
  const att = await client.attest({ model, prompt, response: aiResponse });

  return {
    decision: aiResponse,
    reason: prompt,
    attestationId: att.id,
    timestamp: att.timestamp,
  };
}

// Usage
const decision = await attestedDecision(
  'Should we approve this loan application?',
  'gpt-4o',
  'Approved — credit score 780, income verified'
);

// Anyone can verify this decision was genuinely AI-generated
const isLegit = await client.verify(decision.attestationId);
```

---

## Next.js API Route

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

  try {
    const attestation = await client.attest({ model, prompt, response });
    return NextResponse.json({ attestationId: attestation.id, valid: true });
  } catch (error) {
    return NextResponse.json({ error: 'Attestation failed' }, { status: 500 });
  }
}

// GET /api/attest?id=0x...
export async function GET(req: NextRequest) {
  const id = req.nextUrl.searchParams.get('id');
  if (!id) return NextResponse.json({ error: 'Missing id' }, { status: 400 });

  const valid = await client.verify(id);
  const record = await client.getAttestation(id);

  return NextResponse.json({ valid, record });
}
```

---

## CLI Tool

Simple CLI for attesting and verifying:

```bash
# Attest
npx verified-ai attest \
  --model gpt-4o \
  --prompt "Your prompt" \
  --response "The response" \
  --network base-mainnet

# Verify
npx verified-ai verify 0x3f4a...c9d2 --network base-mainnet
```

---

## Ethers.js Direct Integration

Skip the SDK and call contracts directly:

```typescript
import { ethers } from 'ethers';
import { REGISTRY_ABI, REGISTRY_ADDRESS, VERIFIER_ABI, VERIFIER_ADDRESS } from 'verified-ai-sdk/contracts';

const provider = new ethers.JsonRpcProvider('https://mainnet.base.org');
const signer = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);

const registry = new ethers.Contract(REGISTRY_ADDRESS['base-mainnet'], REGISTRY_ABI, signer);

// Submit attestation
const modelId = 'gpt-4o';
const inputHash = ethers.keccak256(ethers.toUtf8Bytes('my prompt'));
const outputHash = ethers.keccak256(ethers.toUtf8Bytes('ai response'));
const zkProof = '0x...'; // Generated off-chain

const tx = await registry.attest(modelId, inputHash, outputHash, zkProof);
const receipt = await tx.wait();

console.log('Mined in block:', receipt.blockNumber);
```
