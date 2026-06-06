# Verified AI — Documentation

> On-chain attestation and zkML proof verification for AI inference.

---

## Documentation

| Guide | Description |
|---|---|
| [Getting Started](./getting-started.md) | Install the SDK, configure your wallet, submit your first attestation |
| [Architecture](./architecture.md) | System design, contract interaction flow, trust model |
| [SDK Reference](./sdk-reference.md) | Full TypeScript API with types, methods, error codes |
| [Smart Contracts](./contracts.md) | ABI, interfaces, deployed addresses, direct integration |
| [ZK Proofs](./zk-proofs.md) | Proof system, circuit design, privacy model |
| [Examples](./examples.md) | Patterns: Next.js, batch, agent-to-agent, CLI |
| [FAQ](./faq.md) | Common questions answered |
| [Contributing](./contributing.md) | How to contribute to Verified AI |

---

## Contracts (Base Mainnet)

| Contract | Address |
|---|---|
| `AttestationRegistry` | [`0x3dBF622ABC705d2Ec0E07EB0fCbb1AbFDe0281eb`](https://basescan.org/address/0x3dBF622ABC705d2Ec0E07EB0fCbb1AbFDe0281eb) |
| `ZKVerifier` | [`0xc303124d9276Ea7D3d75E94cE7fE5bd3DBec85d3`](https://basescan.org/address/0xc303124d9276Ea7D3d75E94cE7fE5bd3DBec85d3) |

---

## Quick Start

```bash
npm install verified-ai-sdk
```

```typescript
import { VerifiedAI } from 'verified-ai-sdk';

const client = new VerifiedAI({
  network: 'base-mainnet',
  privateKey: process.env.PRIVATE_KEY,
});

const result = await client.attest({
  model: 'gpt-4o',
  prompt: 'Your input',
  response: 'AI output',
});

console.log(result.id);     // bytes32 attestation ID
console.log(result.txHash); // Base mainnet transaction
```

---

## Resources

- **GitHub:** [github.com/NeuroFade/verified-ai](https://github.com/NeuroFade/verified-ai)
- **Landing page:** [neurofade.github.io/verified-ai](https://neurofade.github.io/verified-ai)
- **BaseScan:** [basescan.org](https://basescan.org)
- **License:** MIT
