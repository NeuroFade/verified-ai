# Contributing

Thanks for your interest in contributing to Verified AI. This document covers everything you need to get started.

---

## Ways to contribute

- 🐛 **Bug reports** — open an issue with reproduction steps
- 💡 **Feature requests** — open an issue describing the use case
- 📖 **Documentation** — fix typos, add examples, improve clarity
- 🔧 **Code** — bug fixes, new features, gas optimizations
- 🔍 **Security** — responsible disclosure (see below)

---

## Development setup

### Prerequisites

- Git
- Node.js 18+
- [Foundry](https://getfoundry.sh) (for contracts)
- An RPC endpoint for Base (or Sepolia for testing)

### 1 — Clone the repo

```bash
git clone https://github.com/NeuroFade/verified-ai.git
cd verified-ai
```

### 2 — Install Foundry

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

Verify installation:

```bash
forge --version
cast --version
anvil --version
```

### 3 — Build contracts

```bash
forge build
```

### 4 — Run tests

```bash
# Run all tests
forge test

# Run with verbose output
forge test -vv

# Run a specific test
forge test --match-test testAttest -vvv

# Gas snapshot
forge snapshot
```

### 5 — Install SDK dependencies

```bash
cd sdk
npm install
npm run build
npm test
```

---

## Project structure

```
verified-ai/
├── src/                      # Solidity contracts
│   ├── AttestationRegistry.sol
│   ├── ZKVerifier.sol
│   ├── AgentCapabilityRegistry.sol  # (roadmap)
│   └── AIActCompliance.sol          # (roadmap)
├── test/                     # Forge tests
│   ├── AttestationRegistry.t.sol
│   └── ZKVerifier.t.sol
├── script/                   # Deploy scripts
│   └── Deploy.s.sol
├── sdk/                      # TypeScript SDK
│   ├── src/
│   │   ├── index.ts
│   │   ├── client.ts
│   │   ├── types.ts
│   │   └── zk/
│   ├── package.json
│   └── tsconfig.json
├── docs/                     # This documentation
└── index.html                # Landing page
```

---

## Coding standards

### Solidity

- Solidity `^0.8.24`
- NatSpec comments on all public functions
- Custom errors (not `require` strings) for gas efficiency
- Events for all state changes
- No external dependencies (keep it minimal)

```solidity
// ✅ Good — custom error
error AttestationNotFound(bytes32 id);

// ❌ Bad — string revert
require(exists, "Attestation not found");

// ✅ Good — NatSpec
/// @notice Submits an AI inference attestation on-chain
/// @param modelId Human-readable model identifier
/// @param inputHash keccak256 hash of the prompt
/// @param outputHash keccak256 hash of the response
/// @param zkProof ZK proof bytes (Groth16 format)
/// @return attestationId Unique bytes32 identifier for this attestation
function attest(
    string calldata modelId,
    bytes32 inputHash,
    bytes32 outputHash,
    bytes calldata zkProof
) external returns (bytes32 attestationId);
```

### TypeScript

- Strict TypeScript — no `any`
- Export all public types
- JSDoc on all public methods
- Prefer `async/await` over callbacks
- Test every public method

```typescript
// ✅ Good
async verify(attestationId: `0x${string}`): Promise<boolean> { ... }

// ❌ Bad
async verify(id: any): Promise<any> { ... }
```

---

## Pull request process

1. **Fork** the repo on GitHub
2. **Branch** from `main`:
   ```bash
   git checkout -b feat/my-feature
   # or
   git checkout -b fix/my-bug
   ```
3. **Write tests** — new features need tests, bug fixes need a regression test
4. **Run the test suite**:
   ```bash
   forge test     # contracts
   npm test       # SDK (from sdk/)
   ```
5. **Commit** using [Conventional Commits](https://www.conventionalcommits.org):
   ```
   feat: add batch attestation method
   fix: handle empty proof bytes in ZKVerifier
   docs: add CLI example to examples.md
   test: add forge fuzzing for attest()
   gas: optimize storage layout in AttestationRegistry
   ```
6. **Open a PR** against `main`
7. **Describe the change** — what problem it solves, how it was tested, any trade-offs

---

## Testing

### Contract tests

```bash
# Basic run
forge test

# Verbose (shows logs)
forge test -vv

# Very verbose (shows traces)
forge test -vvvv

# Fuzz a function
forge test --match-test testFuzz -vv

# Coverage
forge coverage
```

### Writing a contract test

```solidity
// test/AttestationRegistry.t.sol
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/AttestationRegistry.sol";

contract AttestationRegistryTest is Test {
    AttestationRegistry registry;
    address attester = address(0xBEEF);

    function setUp() public {
        registry = new AttestationRegistry();
    }

    function testAttest() public {
        vm.prank(attester);

        bytes32 inputHash  = keccak256("hello");
        bytes32 outputHash = keccak256("world");

        bytes32 id = registry.attest("gpt-4o", inputHash, outputHash, "");
        assertTrue(id != bytes32(0));

        AttestationRegistry.Attestation memory att = registry.getAttestation(id);
        assertEq(att.attester, attester);
        assertEq(att.modelId, "gpt-4o");
        assertTrue(att.valid);
    }

    function testFuzz_attest(bytes32 input, bytes32 output) public {
        vm.prank(attester);
        bytes32 id = registry.attest("model", input, output, "");
        assertTrue(registry.verify(id));
    }
}
```

---

## Security

### Responsible disclosure

If you find a security vulnerability, **do not open a public issue**.

Email: `security@verified-ai.xyz` (monitored; PGP key available on request)

Please include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

We aim to respond within 48 hours and resolve critical issues within 7 days.

### Scope

In scope:
- Smart contracts (`src/`)
- SDK (`sdk/`)
- Proof generation pipeline

Out of scope:
- Landing page cosmetics
- Documentation typos (use a regular PR)
- Third-party dependencies

---

## Getting help

- **GitHub Issues** — bugs, feature requests
- **GitHub Discussions** — questions, ideas
- **Telegram** — [@neurofade](https://t.me/neurofade)

---

## Code of Conduct

Be excellent to each other. Constructive criticism welcome; personal attacks are not.
