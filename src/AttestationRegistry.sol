// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title AttestationRegistry
 * @notice Verified AI — Attestation layer for x402 inference on Base
 * @dev Stores cryptographic proofs that AI inference ran correctly on verified hardware
 *
 * Every x402 inference call can optionally anchor an attestation here.
 * Anyone can verify: did model X really produce output Y from input Z?
 *
 * Security fixes (v1.1):
 *   - Added 2-step ownership transfer (transferOwnership / acceptOwnership)
 *   - Emit nonce in AttestationSubmitted event so verifyByComponents() is usable off-chain
 *   - Added string length validation on provider name/teeType
 */
contract AttestationRegistry {

    // ─────────────────────────────────────────────
    // STRUCTS
    // ─────────────────────────────────────────────

    struct Attestation {
        bytes32 modelHash;       // keccak256 of model weights fingerprint
        bytes32 inputHash;       // keccak256 of inference input
        bytes32 outputHash;      // keccak256 of inference output
        bytes32 hardwareId;      // TEE measurement (PCR0 for Nitro, MRTD for TDX)
        address provider;        // address of the inference provider
        uint256 timestamp;       // block.timestamp at submission
        uint256 nonce;           // totalAttestations value at submission (for off-chain replay)
        bool revoked;            // provider can revoke if submission error
    }

    struct ProviderProfile {
        address provider;
        string name;
        string teeType;          // "AWS_NITRO" | "INTEL_TDX" | "AMD_SEV_SNP"
        bytes32 publicKeyHash;   // hash of TEE signing pubkey
        uint256 attestationCount;
        uint256 registeredAt;
        bool active;
    }

    // ─────────────────────────────────────────────
    // STATE
    // ─────────────────────────────────────────────

    mapping(bytes32 => Attestation) public attestations;
    mapping(address => ProviderProfile) public providers;
    mapping(address => bytes32[]) public providerAttestations;
    mapping(bytes32 => bool) public attestationExists;

    address public owner;
    address public pendingOwner;   // 2-step ownership transfer
    uint256 public totalAttestations;
    uint256 public constant VERSION = 2;

    uint256 private constant MAX_STRING_LEN = 256;

    // ─────────────────────────────────────────────
    // EVENTS
    // ─────────────────────────────────────────────

    event AttestationSubmitted(
        bytes32 indexed attestationId,
        address indexed provider,
        bytes32 modelHash,
        bytes32 outputHash,
        uint256 timestamp,
        uint256 nonce           // emitted so verifyByComponents() works off-chain
    );

    event AttestationRevoked(
        bytes32 indexed attestationId,
        address indexed provider
    );

    event ProviderRegistered(
        address indexed provider,
        string name,
        string teeType
    );

    event ProviderDeactivated(address indexed provider);

    // 2-step ownership
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ─────────────────────────────────────────────
    // ERRORS
    // ─────────────────────────────────────────────

    error NotOwner();
    error NotPendingOwner();
    error ProviderNotRegistered();
    error ProviderAlreadyRegistered();
    error AttestationNotFound();
    error AttestationAlreadyRevoked();
    error NotAttestationProvider();
    error ProviderInactive();
    error StringTooLong();
    error ZeroAddress();

    // ─────────────────────────────────────────────
    // CONSTRUCTOR
    // ─────────────────────────────────────────────

    constructor() {
        owner = msg.sender;
    }

    // ─────────────────────────────────────────────
    // OWNERSHIP (2-step)
    // ─────────────────────────────────────────────

    /**
     * @notice Initiate ownership transfer — new owner must call acceptOwnership()
     * @dev Prevents accidental transfer to wrong address
     */
    function transferOwnership(address newOwner) external {
        if (msg.sender != owner) revert NotOwner();
        if (newOwner == address(0)) revert ZeroAddress();
        pendingOwner = newOwner;
        emit OwnershipTransferStarted(owner, newOwner);
    }

    /**
     * @notice Accept pending ownership transfer
     */
    function acceptOwnership() external {
        if (msg.sender != pendingOwner) revert NotPendingOwner();
        emit OwnershipTransferred(owner, pendingOwner);
        owner = pendingOwner;
        pendingOwner = address(0);
    }

    // ─────────────────────────────────────────────
    // PROVIDER MANAGEMENT
    // ─────────────────────────────────────────────

    /**
     * @notice Register as a verified inference provider
     * @param name Human-readable name (e.g. "Eidolon Inference Node #1")
     * @param teeType TEE hardware type
     * @param publicKeyHash Hash of the TEE attestation signing key
     */
    function registerProvider(
        string calldata name,
        string calldata teeType,
        bytes32 publicKeyHash
    ) external {
        if (bytes(name).length > MAX_STRING_LEN) revert StringTooLong();
        if (bytes(teeType).length > MAX_STRING_LEN) revert StringTooLong();
        if (providers[msg.sender].registeredAt != 0) revert ProviderAlreadyRegistered();

        providers[msg.sender] = ProviderProfile({
            provider: msg.sender,
            name: name,
            teeType: teeType,
            publicKeyHash: publicKeyHash,
            attestationCount: 0,
            registeredAt: block.timestamp,
            active: true
        });

        emit ProviderRegistered(msg.sender, name, teeType);
    }

    // ─────────────────────────────────────────────
    // ATTESTATION SUBMISSION
    // ─────────────────────────────────────────────

    /**
     * @notice Submit an inference attestation
     * @param modelHash Fingerprint of the model that ran
     * @param inputHash Hash of the inference input
     * @param outputHash Hash of the inference output
     * @param hardwareId TEE measurement (proves which hardware ran the inference)
     * @return attestationId Unique ID for this attestation
     */
    function submitAttestation(
        bytes32 modelHash,
        bytes32 inputHash,
        bytes32 outputHash,
        bytes32 hardwareId
    ) external returns (bytes32 attestationId) {
        ProviderProfile storage profile = providers[msg.sender];
        if (profile.registeredAt == 0) revert ProviderNotRegistered();
        if (!profile.active) revert ProviderInactive();

        uint256 nonce = totalAttestations;

        attestationId = keccak256(abi.encodePacked(
            msg.sender,
            modelHash,
            inputHash,
            outputHash,
            hardwareId,
            block.timestamp,
            nonce
        ));

        attestations[attestationId] = Attestation({
            modelHash: modelHash,
            inputHash: inputHash,
            outputHash: outputHash,
            hardwareId: hardwareId,
            provider: msg.sender,
            timestamp: block.timestamp,
            nonce: nonce,
            revoked: false
        });

        attestationExists[attestationId] = true;
        providerAttestations[msg.sender].push(attestationId);
        profile.attestationCount++;
        totalAttestations++;

        // Emit nonce so off-chain callers can use verifyByComponents()
        emit AttestationSubmitted(
            attestationId,
            msg.sender,
            modelHash,
            outputHash,
            block.timestamp,
            nonce
        );

        return attestationId;
    }

    // ─────────────────────────────────────────────
    // VERIFICATION
    // ─────────────────────────────────────────────

    /**
     * @notice Verify an attestation by ID
     * @return valid True if attestation exists and is not revoked
     * @return attestation The full attestation data
     */
    function verify(bytes32 attestationId)
        external
        view
        returns (bool valid, Attestation memory attestation)
    {
        if (!attestationExists[attestationId]) revert AttestationNotFound();
        attestation = attestations[attestationId];
        valid = !attestation.revoked;
    }

    /**
     * @notice Verify by recomputing the attestation ID from components
     * @dev Use nonce from the AttestationSubmitted event (field: nonce)
     */
    function verifyByComponents(
        address provider,
        bytes32 modelHash,
        bytes32 inputHash,
        bytes32 outputHash,
        bytes32 hardwareId,
        uint256 timestamp,
        uint256 nonce
    ) external view returns (bool valid, bytes32 attestationId) {
        attestationId = keccak256(abi.encodePacked(
            provider,
            modelHash,
            inputHash,
            outputHash,
            hardwareId,
            timestamp,
            nonce
        ));

        if (!attestationExists[attestationId]) return (false, attestationId);
        valid = !attestations[attestationId].revoked;
    }

    /**
     * @notice Check if a provider is registered and active
     */
    function isVerifiedProvider(address provider) external view returns (bool) {
        return providers[provider].registeredAt != 0 && providers[provider].active;
    }

    /**
     * @notice Get provider attestation history (paginated)
     */
    function getProviderAttestations(address provider, uint256 offset, uint256 limit)
        external
        view
        returns (bytes32[] memory)
    {
        bytes32[] storage all = providerAttestations[provider];
        uint256 total = all.length;
        if (offset >= total) return new bytes32[](0);

        uint256 end = offset + limit > total ? total : offset + limit;
        bytes32[] memory result = new bytes32[](end - offset);
        for (uint256 i = offset; i < end; i++) {
            result[i - offset] = all[i];
        }
        return result;
    }

    // ─────────────────────────────────────────────
    // REVOCATION
    // ─────────────────────────────────────────────

    /**
     * @notice Revoke an attestation (only original provider)
     */
    function revokeAttestation(bytes32 attestationId) external {
        if (!attestationExists[attestationId]) revert AttestationNotFound();
        Attestation storage att = attestations[attestationId];
        if (att.provider != msg.sender) revert NotAttestationProvider();
        if (att.revoked) revert AttestationAlreadyRevoked();

        att.revoked = true;
        emit AttestationRevoked(attestationId, msg.sender);
    }

    // ─────────────────────────────────────────────
    // ADMIN
    // ─────────────────────────────────────────────

    function deactivateProvider(address provider) external {
        if (msg.sender != owner) revert NotOwner();
        providers[provider].active = false;
        emit ProviderDeactivated(provider);
    }
}
