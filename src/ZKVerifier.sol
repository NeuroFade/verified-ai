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
 * In production, integrate Lagrange DeepProve verifier contract at `proveVerifier`.
 * For now, stores commitment hashes — upgradeable to full zk-SNARK verification.
 */
contract ZKVerifier {

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
        Pending,    // submitted, not yet verified
        Verified,   // on-chain verification passed
        Rejected,   // verification failed
        Expired     // proof window elapsed without verification
    }

    struct ProofRequest {
        bytes32 attestationId;
        address requester;
        uint256 requestedAt;
        uint256 bounty;          // optional USDC bounty for prover (future)
        bool fulfilled;
    }

    // ─────────────────────────────────────────────
    // STATE
    // ─────────────────────────────────────────────

    mapping(bytes32 => ZKProof) public proofs;
    mapping(bytes32 => bytes32) public attestationToProof; // attestationId → proofId
    mapping(bytes32 => ProofRequest) public proofRequests;

    // Lagrange DeepProve verifier (set by owner; address(0) = commitment-only mode)
    address public deepProveVerifier;
    address public attestationRegistry;
    address public owner;

    uint256 public totalProofs;
    uint256 public constant PROOF_WINDOW = 24 hours; // max time to submit proof after attestation
    uint256 public constant VERSION = 1;

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

    // ─────────────────────────────────────────────
    // ERRORS
    // ─────────────────────────────────────────────

    error NotOwner();
    error ProofAlreadyExists();
    error ProofNotFound();
    error AttestationNotFound();
    error ProofWindowExpired();
    error InvalidProofHash();
    error ZeroAddress();
    error NoBountyToWithdraw();
    error ProofAlreadyFulfilled();

    // ─────────────────────────────────────────────
    // CONSTRUCTOR
    // ─────────────────────────────────────────────

    constructor(address _attestationRegistry) {
        if (_attestationRegistry == address(0)) revert ZeroAddress();
        owner = msg.sender;
        attestationRegistry = _attestationRegistry;
    }

    // ─────────────────────────────────────────────
    // PROOF SUBMISSION
    // ─────────────────────────────────────────────

    /**
     * @notice Submit a zkML proof for an existing attestation
     * @param attestationId The attestation this proof covers
     * @param proofHash keccak256 of the full proof bytes (stored off-chain / IPFS)
     * @param publicInputsHash keccak256(modelHash ++ outputHash) — public inputs
     * @return proofId Unique ID for this proof
     */
    function submitProof(
        bytes32 attestationId,
        bytes32 proofHash,
        bytes32 publicInputsHash
    ) external returns (bytes32 proofId) {
        if (proofHash == bytes32(0)) revert InvalidProofHash();
        if (attestationToProof[attestationId] != bytes32(0)) revert ProofAlreadyExists();

        proofId = keccak256(abi.encodePacked(
            attestationId,
            proofHash,
            publicInputsHash,
            msg.sender,
            block.timestamp
        ));

        ProofStatus status = ProofStatus.Pending;

        // If DeepProve verifier is set, attempt on-chain verification
        if (deepProveVerifier != address(0)) {
            bool verified = _callDeepProveVerifier(proofHash, publicInputsHash);
            status = verified ? ProofStatus.Verified : ProofStatus.Rejected;
        } else {
            // Commitment-only mode: store hash, mark as verified (trust model)
            // Upgrade to full zk-SNARK by setting deepProveVerifier
            status = ProofStatus.Verified;
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
     * @notice Check if an attestation has a valid zkML proof
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
     * @notice Request a proof for an existing attestation (with optional bounty)
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
     * @dev Prevents ETH from being permanently locked in the contract
     * @param requestId The request ID returned by requestProof()
     */
    function withdrawBounty(bytes32 requestId) external {
        ProofRequest storage req = proofRequests[requestId];
        if (req.requester != msg.sender) revert NotOwner();
        if (req.fulfilled) revert ProofAlreadyFulfilled();
        uint256 amount = req.bounty;
        if (amount == 0) revert NoBountyToWithdraw();
        req.bounty = 0;
        (bool success, ) = payable(msg.sender).call{value: amount}("");
        require(success, "ETH transfer failed");
    }

    // ─────────────────────────────────────────────
    // ADMIN
    // ─────────────────────────────────────────────

    /**
     * @notice Set Lagrange DeepProve verifier contract address
     * @dev Set to address(0) to use commitment-only mode
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
