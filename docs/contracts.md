# Smart Contracts

Two contracts. Deployed on Base mainnet.

---

## Deployments

| Contract | Network | Address | BaseScan |
|---|---|---|---|
| `AttestationRegistry` | Base Mainnet | `0x3dBF622ABC705d2Ec0E07EB0fCbb1AbFDe0281eb` | [View ↗](https://basescan.org/address/0x3dBF622ABC705d2Ec0E07EB0fCbb1AbFDe0281eb) |
| `ZKVerifier` | Base Mainnet | `0xc303124d9276Ea7D3d75E94cE7fE5bd3DBec85d3` | [View ↗](https://basescan.org/address/0xc303124d9276Ea7D3d75E94cE7fE5bd3DBec85d3) |
| `AttestationRegistry` | Base Sepolia | `pending` | — |
| `ZKVerifier` | Base Sepolia | `pending` | — |

---

## AttestationRegistry

Central registry for all AI attestation records. Every verified AI inference is anchored here as an immutable on-chain record.

### Structs

```solidity
struct Attestation {
    bytes32 id;             // Unique attestation identifier
    address attester;       // Address that submitted
    string  modelId;        // AI model identifier (e.g. "gpt-4o")
    bytes32 inputHash;      // keccak256(prompt)
    bytes32 outputHash;     // keccak256(response)
    bytes32 proofHash;      // keccak256(zkProof)
    uint256 timestamp;      // Block timestamp
    bool    valid;          // ZK proof validity
}
```

### Events

```solidity
event AttestationCreated(
    bytes32 indexed id,
    address indexed attester,
    string  modelId,
    uint256 timestamp
);

event AttestationInvalidated(
    bytes32 indexed id,
    address indexed reporter,
    string  reason
);
```

### Write functions

```solidity
// Submit an attestation
function attest(
    string  calldata modelId,
    bytes32          inputHash,
    bytes32          outputHash,
    bytes   calldata zkProof
) external returns (bytes32 attestationId);
```

### Read functions

```solidity
// Fetch a record
function getAttestation(bytes32 id)
    external view returns (Attestation memory);

// Check validity
function verify(bytes32 id)
    external view returns (bool);

// List by submitter
function getAttestationsByAttester(address attester)
    external view returns (bytes32[] memory);

// List by model
function getAttestationsByModel(string calldata modelId)
    external view returns (bytes32[] memory);

// Registry stats
function totalAttestations()
    external view returns (uint256);
```

---

## ZKVerifier

Validates zero-knowledge proof commitments. Compatible with Lagrange DeepProve proof format. Initialized with a reference to `AttestationRegistry`.

### Constructor

```solidity
constructor(address _attestationRegistry)
```

### Structs

```solidity
struct ZKProof {
    bytes32 attestationId;    // Links to AttestationRegistry entry
    bytes32 proofHash;        // keccak256 of proof bytes (stored off-chain)
    bytes32 publicInputsHash; // keccak256(modelHash ++ outputHash)
    address prover;           // Who submitted the proof
    uint256 timestamp;
    bool    valid;
}
```

### Events

```solidity
event ProofSubmitted(
    bytes32 indexed proofId,
    bytes32 indexed attestationId,
    address indexed prover,
    uint256 timestamp
);

event ProofVerified(
    bytes32 indexed proofHash,
    bool    valid,
    uint256 timestamp
);
```

### Write functions

```solidity
// Submit a proof commitment
function submitProof(
    bytes32 attestationId,
    bytes32 proofHash,
    bytes32 publicInputsHash
) external returns (bytes32 proofId);
```

### Read functions

```solidity
// Check if attestation has valid proof
function verifyProof(bytes32 attestationId)
    external view returns (bool);

// Check proof by hash
function isProofVerified(bytes32 proofHash)
    external view returns (bool);

// Fetch full proof record
function getProof(bytes32 proofId)
    external view returns (ZKProof memory);
```

---

## Direct interaction (ethers.js v6)

```typescript
import { ethers } from 'ethers';

const provider = new ethers.JsonRpcProvider('https://mainnet.base.org');
const signer = new ethers.Wallet(process.env.PRIVATE_KEY!, provider);

// AttestationRegistry
const registry = new ethers.Contract(
  '0x3dBF622ABC705d2Ec0E07EB0fCbb1AbFDe0281eb',
  REGISTRY_ABI,
  signer
);

// ZKVerifier
const verifier = new ethers.Contract(
  '0xc303124d9276Ea7D3d75E94cE7fE5bd3DBec85d3',
  VERIFIER_ABI,
  signer
);

// Attest
const inputHash  = ethers.keccak256(ethers.toUtf8Bytes('my prompt'));
const outputHash = ethers.keccak256(ethers.toUtf8Bytes('ai response'));
const tx = await registry.attest('gpt-4o', inputHash, outputHash, '0x');
const receipt = await tx.wait();

// Verify
const valid = await verifier.verifyProof(attestationId);
```

---

## Security

### Design principles

1. **Immutability** — Attestations cannot be modified after submission
2. **Trustlessness** — Verification requires no trusted third party
3. **Permissionless** — Any address can submit or verify attestations
4. **Gas efficiency** — Proof bytes hashed off-chain; only commitments stored

### Audit status

- [ ] Internal review complete
- [ ] External audit: pending
- [ ] Bug bounty: TBA

---

## Verifying on BaseScan

1. Go to [BaseScan](https://basescan.org/address/0x3dBF622ABC705d2Ec0E07EB0fCbb1AbFDe0281eb)
2. Click **Read Contract**
3. Call `getAttestation(bytes32 id)` with your attestation ID
4. Check the `valid` field returns `true`
