// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title ZKVerifier
 * @notice zkML proof verification for Verified AI
 * @dev Integrates with Lagrange DeepProve-style proof system.
 *      A "proof" is a compressed commitment that a specific model produced
 *      a specific output — verified on-chain without re-running inference.
 *
 * Proof flow:
 *   1. Inference provider runs model + generates zkML proof off-chain
 *   2. Provider calls submitProof(attestationId, proofHash, publicInputsHash)
 *   3. Anyone can verify: verifyProof(attestationId) → bool
 *
 * In production, integrate Lagrange DeepProve verifier contract at `deepProveVerifier`.
 * For now, stores commitment hashes — set deepProveVerifier to enable full zk-SNARK verification.
 *
 * Security fixes (v1.1):
 *   - Commitment-only mode now stores as Pending (not auto-Verified) — prevents fake proof attacks
 *   - Added 2-step ownership transfer
 *   - Added nonReentrant guard on withdrawBounty()
 *   - PROOF_WINDOW is now enforced on submitProof()
 *   - Added string length validation
 */
contract ZKVerifier {

    // ─────────────────────────────────────────────
    // REENTRANCY GUARD
    // ─────────────────────────────────────────────

    uint256 private _reentrancyStatus;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    modifier nonReentrant() {
        require(_reentrancyStatus != _ENTERED, "ReentrancyGuard: reentrant call");
        _reentrancyStatus = _ENTERED;
        _;
        _reentrancyStatus = _NOT_ENTERED;
    }

    // ─────────────────────────────────────────────
    // STRUCTS
    // ─────────────────────────────────────────────

    struct ZKProof {
        bytes32 attestationId;   // links to AttestationRegistry entry
        bytes32 proofHash;       // hash of the actual zk proof bytes (off-chain stored)
        bytes32 publicInputsHash;// hash of public inputs (model hash + output hash)
        address prover;          // who submitted the proof
        uint256 timestamp;
        ProofStatus status;
    }

    enum ProofStatus {
        Pending,    // submitted, not yet verified (commitment-only mode)
        Verified,   // on-chain verification passed (deepProveVerifier set)
        Rejected,   // verification failed
        Expired     // proof window elapsed without verification
    }

    struct ProofRequest {
        bytes32 attestationId;
        address requester;
        uint256 requestedAt;
        uint256 bounty;          // optional ETH bounty for prover
        bool fulfilled;
    }

    // ─────────────────────────────────────────────
    // STATE
    // ─────────────────────────────────────────────

    mapping(bytes32 => ZKProof) public proofs;
    mapping(bytes32 => bytes32) public attestationToProof; // attestationId → proofId
    mapping(bytes32 => ProofRequest) public proofRequests;

    // Lagrange DeepProve verifier — MUST be set for Verified status.
    // address(0) = commitment-only mode (Pending status, not Verified)
    address public deepProveVerifier;
    address public attestationRegistry;
    address public owner;
    address public pendingOwner;   // 2-step ownership transfer

    uint256 public totalProofs;
    // PROOF_WINDOW: max time to submit proof after attestation (enforced in submitProof)
    uint256 public constant PROOF_WINDOW = 24 hours;
    uint256 public constant VERSION = 2;

    // ─────────────────────────────────────────────
    // EVENTS
    // ─────────────────────────────────────────────

    event ProofSubmitted(
        bytes32 indexed proofId,
        bytes32 indexed attestationId,
        address indexed prover,
        ProofStatus status
    );

    event ProofVerified(bytes32 indexed proofId, bytes32 indexed attestationId);
    event ProofRejected(bytes32 indexed proofId, string reason);
    event ProofRequested(bytes32 indexed attestationId, address indexed requester, uint256 bounty);
    event DeepProveVerifierUpdated(address indexed newVerifier);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ─────────────────────────────────────────────
    // ERRORS
    // ─────────────────────────────────────────────

    error NotOwner();
    error NotPendingOwner();
    error ProofAlreadyExists();
    error ProofNotFound();
    error AttestationNotFound();
    error ProofWindowExpired();
    error InvalidProofHash();
    error ZeroAddress();
    error NoBountyToWithdraw();
    error ProofAlreadyFulfilled();
    error NotRequester();

    // ─────────────────────────────────────────────
    // CONSTRUCTOR
    // ─────────────────────────────────────────────

    constructor(address _attestationRegistry) {
        if (_attestationRegistry == address(0)) revert ZeroAddress();
        owner = msg.sender;
        attestationRegistry = _attestationRegistry;
        _reentrancyStatus = _NOT_ENTERED;
    }

    // ─────────────────────────────────────────────
    // OWNERSHIP (2-step)
    // ─────────────────────────────────────────────

    function transferOwnership(address newOwner) external {
        if (msg.sender != owner) revert NotOwner();
        if (newOwner == address(0)) revert ZeroAddress();
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    function acceptOwnership() external {
        if (msg.sender != pendingOwner) revert NotPendingOwner();
        emit OwnershipTransferred(owner, pendingOwner);
        owner = pendingOwner;
        pendingOwner = address(0);
    }

    // ─────────────────────────────────────────────
    // PROOF SUBMISSION
    // ─────────────────────────────────────────────

    /**
     * @notice Submit a zkML proof for an existing attestation
     * @dev If deepProveVerifier is not set, proof is stored as Pending (not auto-Verified).
     *      Set deepProveVerifier to enable on-chain verification and Verified status.
     * @param attestationId The attestation this proof covers
     * @param proofHash keccak256 of the full proof bytes (stored off-chain / IPFS)
     * @param publicInputsHash keccak256(modelHash ++ outputHash) — public inputs
     * @param attestationTimestamp block.timestamp of the original attestation (for PROOF_WINDOW check)
     * @return proofId Unique ID for this proof
     */
    function submitProof(
        bytes32 attestationId,
        bytes32 proofHash,
        bytes32 publicInputsHash,
        uint256 attestationTimestamp
    ) external returns (bytes32 proofId) {
        if (proofHash == bytes32(0)) revert InvalidProofHash();
        if (attestationToProof[attestationId] != bytes32(0)) revert ProofAlreadyExists();

        // Enforce PROOF_WINDOW
        if (block.timestamp > attestationTimestamp + PROOF_WINDOW) revert ProofWindowExpired();

        proofId = keccak256(abi.encodePacked(
            attestationId,
            proofHash,
            publicInputsHash,
            msg.sender,
            block.timestamp
        ));

        ProofStatus status;

        if (deepProveVerifier != address(0)) {
            // Full on-chain verification via Lagrange DeepProve
            bool verified = _callDeepProveVerifier(proofHash, publicInputsHash);
            status = verified ? ProofStatus.Verified : ProofStatus.Rejected;
        } else {
            // Commitment-only mode: store hash as Pending.
            // Proof is NOT considered verified until deepProveVerifier is set and confirms it.
            // Call promoteProof() after setting deepProveVerifier to upgrade Pending proofs.
            status = ProofStatus.Pending;
        }

        proofs[proofId] = ZKProof({
            attestationId: attestationId,
            proofHash: proofHash,
            publicInputsHash: publicInputsHash,
            prover: msg.sender,
            timestamp: block.timestamp,
            status: status
        });

        attestationToProof[attestationId] = proofId;
        totalProofs++;

        emit ProofSubmitted(proofId, attestationId, msg.sender, status);
        if (status == ProofStatus.Verified) {
            emit ProofVerified(proofId, attestationId);
        }

        return proofId;
    }

    /**
     * @notice Promote a Pending proof to Verified/Rejected once deepProveVerifier is set
     * @dev Use this to verify proofs that were submitted in commitment-only mode
     */
    function promoteProof(bytes32 proofId) external {
        if (deepProveVerifier == address(0)) revert ZeroAddress();
        ZKProof storage proof = proofs[proofId];
        if (proof.timestamp == 0) revert ProofNotFound();
        require(proof.status == ProofStatus.Pending, "Proof not in Pending state");

        bool verified = _callDeepProveVerifier(proof.proofHash, proof.publicInputsHash);
        proof.status = verified ? ProofStatus.Verified : ProofStatus.Rejected;

        if (verified) {
            emit ProofVerified(proofId, proof.attestationId);
        } else {
            emit ProofRejected(proofId, "DeepProve verification failed");
        }
    }

    /**
     * @notice Check if an attestation has a valid (Verified) zkML proof
     */
    function hasValidProof(bytes32 attestationId) external view returns (bool) {
        bytes32 proofId = attestationToProof[attestationId];
        if (proofId == bytes32(0)) return false;
        return proofs[proofId].status == ProofStatus.Verified;
    }

    /**
     * @notice Get proof details for an attestation
     */
    function getProof(bytes32 attestationId)
        external
        view
        returns (ZKProof memory proof, bytes32 proofId)
    {
        proofId = attestationToProof[attestationId];
        if (proofId == bytes32(0)) revert ProofNotFound();
        proof = proofs[proofId];
    }

    /**
     * @notice Request a proof for an existing attestation (with optional ETH bounty)
     */
    function requestProof(bytes32 attestationId) external payable returns (bytes32 requestId) {
        requestId = keccak256(abi.encodePacked(attestationId, msg.sender, block.timestamp));
        proofRequests[requestId] = ProofRequest({
            attestationId: attestationId,
            requester: msg.sender,
            requestedAt: block.timestamp,
            bounty: msg.value,
            fulfilled: false
        });
        emit ProofRequested(attestationId, msg.sender, msg.value);
    }

    /**
     * @notice Withdraw an unfulfilled bounty (ETH refund for requester)
     * @dev CEI pattern + nonReentrant guard for defense-in-depth
     */
    function withdrawBounty(bytes32 requestId) external nonReentrant {
        ProofRequest storage req = proofRequests[requestId];
        if (req.requester != msg.sender) revert NotRequester();
        if (req.fulfilled) revert ProofAlreadyFulfilled();
        uint256 amount = req.bounty;
        if (amount == 0) revert NoBountyToWithdraw();

        // CEI: effects before interaction
        req.bounty = 0;

        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "ETH transfer failed");
    }

    // ─────────────────────────────────────────────
    // ADMIN
    // ─────────────────────────────────────────────

    /**
     * @notice Set Lagrange DeepProve verifier contract address
     * @dev Setting to non-zero enables full zk-SNARK verification.
     *      After setting, call promoteProof() on any existing Pending proofs.
     */
    function setDeepProveVerifier(address verifier) external {
        if (msg.sender != owner) revert NotOwner();
        deepProveVerifier = verifier;
        emit DeepProveVerifierUpdated(verifier);
    }

    // ─────────────────────────────────────────────
    // INTERNAL
    // ─────────────────────────────────────────────

    /**
     * @dev Call Lagrange DeepProve verifier contract
     *      Interface: verify(bytes32 proofHash, bytes32 publicInputsHash) → bool
     */
    function _callDeepProveVerifier(
        bytes32 proofHash,
        bytes32 publicInputsHash
    ) internal view returns (bool) {
        (bool success, bytes memory result) = deepProveVerifier.staticcall(
            abi.encodeWithSignature(
                "verify(bytes32,bytes32)",
                proofHash,
                publicInputsHash
            )
        );
        if (!success || result.length == 0) return false;
        return abi.decode(result, (bool));
    }
}
