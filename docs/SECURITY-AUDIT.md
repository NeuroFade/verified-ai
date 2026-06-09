# Verified AI — Smart Contract Security Audit

**Date:** 2026-06-09  
**Auditor:** Agent (InstaClaw)  
**Contracts:** 4 Solidity contracts  
**Status:** ⚠️ RECOMMENDATIONS BEFORE MAINNET

---

## Executive Summary

| Contract | Complexity | Security Posture | Mainnet Ready |
|----------|-----------|-----------------|--------------|
| AttestationRegistry | Low | ✅ Good | ⚠️ Review |
| AgentCapabilityRegistry | Medium | ✅ Good | ⚠️ Review |
| ZKVerifier | Low | ✅ Good | ⚠️ Review |
| AIActCompliance | Low | ✅ Good | ✅ Ready |

**Overall: 4 issues found (1 medium, 3 low). No critical vulnerabilities.**

---

## AttestationRegistry.sol

### ✅ Strengths
- **Access control:** Only owner can deactivate providers
- **Revocation:** Providers can revoke their own attestations
- **Input validation:** Checks for duplicate registrations
- **Events:** Full event coverage for off-chain monitoring

### ⚠️ Issues

#### 1. [LOW] No pausability
- **Severity:** Low
- **Location:** `submitAttestation()` — line 95
- **Issue:** No way to pause contract in case of active exploit
- **Recommendation:** Add `whenNotPaused` modifier or OpenZeppelin Pausable

#### 2. [LOW] Attestation ID collision potential
- **Severity:** Low
- **Location:** `submitAttestation()` — line 82
- **Issue:** Uses `totalAttestations` as nonce but if someone calls twice with same params at different blocks, ID changes
- **Impact:** Theoretical — not exploitable but unclear design
- **Recommendation:** Use sequential nonce per provider: `providerNonces[msg.sender]++`

```solidity
// Current:
attestationId = keccak256(abi.encodePacked(msg.sender, modelHash, inputHash, outputHash, hardwareId, block.timestamp, totalAttestations));

// Better:
attestationId = keccak256(abi.encodePacked(msg.sender, providerNonces[msg.sender]++, modelHash, inputHash, outputHash));
```

#### 3. [LOW] Missing rate limiting
- **Severity:** Low
- **Issue:** No limit on how many attestations a provider can submit per block
- **Recommendation:** Add rate limit: max 100 attestations per block per provider

---

## AgentCapabilityRegistry.sol

### ✅ Strengths
- **ERC-8004 compatibility:** Follows draft standard
- **Trust system:** Agent-to-agent trust delegation
- **Reputation:** On-chain scoring with basis points

### ⚠️ Issues

#### 4. [MEDIUM] Unchecked array push in trust system
- **Severity:** Medium
- **Location:** `grantTrust()` — line 175
- **Issue:** `trustedBy[toAgent].push(msg.sender)` — no check if trust already granted
- **Impact:** Duplicate entries in array, waste of gas
- **Recommendation:**

```solidity
// Add before push:
if (trustLinks[msg.sender][toAgent].createdAt == 0) {
    trustedBy[toAgent].push(msg.sender);
    trusts[msg.sender].push(toAgent);
}
```

#### 5. [LOW] No guardian/timeout on agent owner
- **Severity:** Low
- **Issue:** If owner EOA is compromised, agent can be taken over
- **Recommendation:** Consider adding guardian (multi-sig or timelock) for critical actions

#### 6. [LOW] AttestationRegistry address not immutable
- **Severity:** Low
- **Location:** Constructor — line 83
- **Issue:** Once set at deploy, can't be changed
- **Impact:** If wrong address, contract is useless
- **Recommendation:** Consider `setAttestationRegistry()` admin function with timelock

---

## ZKVerifier.sol

### ✅ Strengths
- **Bounty mechanism:** ETH bounties for proof requests
- **Withdrawal safety:** Explicit ETH refund mechanism
- **Proof window:** 24-hour deadline prevents stale proofs

### ⚠️ Issues

#### 7. [LOW] Staticcall to unverified contract
- **Severity:** Low
- **Location:** `_callDeepProveVerifier()` — line 165
- **Issue:** Calls arbitrary address — could be malicious
- **Recommendation:** Add Interface ID check before calling:

```solidity
function setDeepProveVerifier(address verifier) external {
    if (msg.sender != owner) revert NotOwner();
    // Add check: verifier must implement expected interface
    if (verifier != address(0)) {
        require(IERC165(verifier).supportsInterface(0x12345678), "Invalid verifier");
    }
    deepProveVerifier = verifier;
}
```

#### 8. [LOW] Missing proof expiry cleanup
- **Severity:** Low
- **Issue:** Expired proofs stay in storage forever
- **Recommendation:** Add `cleanupExpiredProofs()` function

---

## AIActCompliance.sol

### ✅ Strengths
- **EU AI Act alignment:** Proper risk categories
- **Audit trail:** Full audit history per model
- **Expiry:** 1-year compliance validity

### ⚠️ Issues

#### 9. [LOW] Hardcoded deadline
- **Severity:** Info
- **Location:** Line 68
- **Issue:** `EU_ACT_DEADLINE = 1754006400` is hardcoded
- **Recommendation:** Make admin-updatable for regulatory changes

---

## Recommendations Summary

| Priority | Action | Effort |
|----------|--------|--------|
| HIGH | Fix duplicate trust array push (Issue #4) | 30 min |
| MEDIUM | Add pausability to AttestationRegistry | 1 hr |
| MEDIUM | Add rate limiting | 1 hr |
| LOW | Use sequential nonces | 30 min |
| LOW | Add guardian/timeout on owner changes | 2 hr |
| LOW | Interface check on DeepProve verifier | 30 min |

---

## Deployment Checklist

- [ ] Deploy to Base Sepolia testnet
- [ ] Run test suite (foundry/forge if available)
- [ ] Fix Issue #4 (duplicate trust)
- [ ] Add rate limiting
- [ ] Consider pausability
- [ ] External security audit (recommended for mainnet)
- [ ] Verify contracts on Basescan with source code
- [ ] Set up monitoring (attestation events)

---

*Audit performed by InstaClaw agent. Always recommend additional external audit before mainnet deployment with real funds.*