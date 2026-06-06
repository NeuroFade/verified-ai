# Smart Contracts

Verified AI is composed of two core smart contracts deployed on Base mainnet.

---

## Deployments

| Contract | Network | Address |
|---|---|---|
| `AttestationRegistry` | Base Mainnet | [`0x3dBF622ABC705d2Ec0E07EB0fCbb1AbFDe0281eb`](https://basescan.org/address/0x3dBF622ABC705d2Ec0E07EB0fCbb1AbFDe0281eb) |
| `AttestationRegistry` | Base Sepolia | `pending` |
| `ZKVerifier` | Base Mainnet | [`0xc303124d9276Ea7D3d75E94cE7fE5bd3DBec85d3`](https://basescan.org/address/0xc303124d9276Ea7D3d75E94cE7fE5bd3DBec85d3) |
| `ZKVerifier` | Base Sepolia | `pending` |

---

## AttestationRegistry

The central contract that stores all attestation records. Every verified AI inference is anchored here as an immutable on-chain record.

### ABI (Core Methods)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IAttestationRegistry {

    // ─── Structs ───────────────────────────────────────────────
    struct Attestation {
        bytes32 id;          // Unique identifier
        address attester;    // Who submitted this attestation
        string modelId;      // AI model identifier
        bytes32 inputHash;   // keccak256(prompt)
        bytes32 outputHash;  // keccak256(response)
        bytes32 proofHash;   // keccak256(zkProof)
        uint256 timestamp;   // Block timestamp
        bool valid;          // ZK proof validity
    }

    // ─── Events ────────────────────────────────────────────────
    event AttestationCreated(
        bytes32 indexed id,
        address indexed attester,
        string modelId,
        uint256 timestamp
    );

    event AttestationInvalidated(
        bytes32 indexed id,
        address indexed reporter,
        string reason
    );

    // ─── Write ─────────────────────────────────────────────────
    function attest(
        string calldata modelId,
        bytes32 inputHash,
        bytes32 outputHash,
        bytes calldata zkProof
    ) external returns (bytes32 attestationId);

    // ─── Read ──────────────────────────────────────────────────
    function getAttestation(bytes32 id)
        external view returns (Attestation memory);

    function verify(bytes32 id)
        external view returns (bool);

    function getAttestationsByAttester(address attester)
        external view returns (bytes32[] memory);

    function getAttestationsByModel(string calldata modelId)
        external view returns (bytes32[] memory);

    function totalAttestations()
        external view returns (uint256);
}
```

---

## ZKVerifier

Validates zero-knowledge proofs generated off-chain for each AI inference. Uses Groth16 proof system.

### ABI

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IZKVerifier {

    // ─── Events ────────────────────────────────────────────────
    event ProofVerified(
        bytes32 indexed proofHash,
        bool valid,
        uint256 timestamp
    );

    // ─── Write ─────────────────────────────────────────────────
    function verifyProof(
        bytes calldata proof,
        bytes32 inputHash,
        bytes32 outputHash
    ) external returns (bool valid);

    // ─── Read ──────────────────────────────────────────────────
    function verifyProofView(
        bytes calldata proof,
        bytes32 inputHash,
        bytes32 outputHash
    ) external view returns (bool valid);

    function isProofVerified(bytes32 proofHash)
        external view returns (bool);
}
```

---

## Security

### Audit Status
- [ ] Internal review complete
- [ ] External audit pending
- [ ] Bug bounty: TBA

### Design Principles

1. **Immutability** — Attestations cannot be modified after submission
2. **Trustlessness** — Verification requires no trusted third party
3. **Permissionless** — Any address can submit or verify attestations
4. **Gas efficiency** — Minimal on-chain storage; proofs are hashed, not stored

---

## Interacting Directly (ethers.js v6)

```typescript
import { ethers } from 'ethers';
import { REGISTRY_ABI, REGISTRY_ADDRESS } from 'verified-ai-sdk/contracts';

const provider = new ethers.JsonRpcProvider('https://mainnet.base.org');
const signer = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);

const registry = new ethers.Contract(
  REGISTRY_ADDRESS['base-mainnet'],
  REGISTRY_ABI,
  signer
);

// Read
const att = await registry.getAttestation('0x3f4a...c9d2');

// Write
const tx = await registry.attest(modelId, inputHash, outputHash, proof);
await tx.wait();
```

---

## Verifying on BaseScan

All attestations are publicly verifiable:

1. Go to [BaseScan](https://basescan.org)
2. Search the `AttestationRegistry` contract address
3. Click **Read Contract** → `getAttestation`
4. Paste the attestation ID
5. Verify the `valid` field returns `true`
