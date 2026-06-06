# FAQ

Frequently asked questions about Verified AI.

---

## General

### What problem does Verified AI solve?

When an AI model produces output, there's currently no way for a third party to verify:
1. Which model actually ran (not a cheaper substitute)
2. What the exact input was (no tampering)
3. What the exact output was (not fabricated)

Verified AI creates an immutable, on-chain record of every inference — anchored by cryptographic hashes and eventually a full ZK proof.

---

### How is this different from just logging?

Logs are mutable — they live on servers controlled by the provider, and can be altered or deleted. On-chain records are:

- **Immutable** — cannot be changed after submission
- **Permissionless** — anyone can read and verify, no API key needed
- **Trustless** — verification doesn't require trusting the provider
- **Permanent** — as long as Base exists, the records exist

---

### Do I need to reveal my prompts on-chain?

No. Only **hashes** of the prompt and response are stored — `keccak256(prompt)` and `keccak256(response)`. The raw content never touches the chain.

With ZK proofs (v2), even the hash pre-images are kept private inside the circuit. Consumers can verify validity without learning anything about the content.

---

### Is this useful without full ZK proofs?

Yes. Even in v1 (without full on-chain proof verification), the system provides:

- **Timestamp proof** — when a specific model claim was made
- **Hash binding** — attestation is cryptographically tied to specific input/output hashes
- **Attester accountability** — who submitted the attestation (their signing address)
- **Immutability** — cannot be retracted or modified

Full trustlessness (where the proof itself is verified on-chain) ships in v2.

---

## Technical

### What is Groth16?

Groth16 is a zero-knowledge proof system that produces extremely small proofs (~256 bytes) that can be verified efficiently. It's the most widely used ZK system for on-chain verification. It requires a one-time "trusted setup" ceremony — Verified AI uses the Hermez Phase 2 ceremony (1000+ participants).

---

### Why Base and not Ethereum mainnet?

Cost. A single attestation on Ethereum mainnet costs ~$1-5 in gas. On Base, the same operation costs ~$0.002. At scale (thousands of inferences per day), this difference is the line between economically viable and not.

Base also inherits Ethereum's security via optimistic rollup — same trust guarantees, fraction of the cost.

---

### Can I use this without the SDK?

Yes. The contracts are standard Solidity and can be called via any Ethereum tooling:

- `ethers.js` / `viem` — direct contract interaction
- `cast` (Foundry) — CLI calls
- `web3.py` — Python
- Any JSON-RPC client

See [Contracts](./contracts.md) for the ABI and direct integration examples.

---

### What's the proof size?

~256 bytes for a Groth16 proof. The proof bytes are NOT stored on-chain — only the `keccak256` commitment is stored. This keeps gas costs low while preserving verifiability.

---

### What happens if the prover is down?

Attestation (storing input/output hashes) and ZK proof submission are independent operations. If the prover is unavailable:

- Attestations can still be submitted (hash-only, no proof)
- Proof can be submitted later using the `attestationId`
- Attestation remains in the registry regardless

---

### Can attestations be deleted or invalidated?

Attestation records are immutable — they cannot be deleted. However, an attestation can be **invalidated** (marked invalid) by the contract owner if a proof is later found to be incorrect. The record remains, but the `valid` flag is set to `false`.

---

## Security

### What are the current trust assumptions?

In v1:

1. **Client-side hashing** — `inputHash` and `outputHash` are computed by the provider's client. We trust they hashed faithfully. (TEE removes this assumption in v2.)
2. **Proof commitment only** — The proof `π` is hashed and stored; the pairing check (full on-chain verification) ships in v2.
3. **Model ID is self-declared** — Providers claim their own model IDs. Reputation and verification will be added.

---

### Has the contract been audited?

Not yet. External audit is on the roadmap for v1.1. The contracts are open source — review them at [github.com/NeuroFade/verified-ai](https://github.com/NeuroFade/verified-ai).

**Use in production at your own risk until the audit is complete.**

---

### Can someone fake an attestation?

Technically, anyone can submit an attestation claiming any model ID. What they can't fake:

- The attester's address (their wallet signs the tx)
- The timestamp (set by the block)
- The input/output hashes (pre-images not revealed)

With full ZK proof verification (v2), model binding becomes cryptographic — you'd need to know the actual model weights to forge a valid proof.

---

## SDK & Integration

### What networks are supported?

| Network | Status |
|---|---|
| Base Mainnet | ✅ Live |
| Base Sepolia | 🚧 Coming soon |
| Ethereum Mainnet | 📋 Roadmap |
| Arbitrum | 📋 Roadmap |

---

### Can I use this with any AI model?

The `modelId` field is a free-form string — you can attest any model's output. The SDK supports `gpt-4o`, `claude-3-5-sonnet`, and any custom identifier.

For automatic proof generation (where the SDK generates the ZK proof), the model needs to be supported by the prover network. Currently in development.

---

### Is there a rate limit?

No. The contracts are permissionless — there's no rate limit at the protocol level. The only limit is gas budget. At ~$0.002 per attestation on Base, you could submit 500 attestations for $1.

---

### What's the SDK license?

MIT — use it anywhere, commercial or not.

---

## Costs

### How much does an attestation cost?

~$0.002–$0.005 on Base mainnet (varies with gas price). This covers:
- `attest()` call: ~120,000 gas
- `submitProof()` call: ~80,000 gas

Read operations (`verify()`, `getAttestation()`) are free.

---

### Do I need ETH on Base?

Yes — a small amount for gas. ~0.001 ETH (~$2.50) covers thousands of attestations.

Get Base ETH:
- Bridge from Ethereum: [bridge.base.org](https://bridge.base.org)
- Buy directly: Coinbase, Kraken (Base network option)
- Faucet (testnet): [Coinbase faucet](https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet)
