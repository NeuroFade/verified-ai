// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title AIActCompliance
 * @notice EU AI Act compliance module for Verified AI
 * @dev Implements on-chain training data commitments as required by:
 *      - EU AI Act Article 10 (training data requirements)
 *      - EU AI Act Article 13 (transparency obligations)
 *      - EU AI Act Article 17 (quality management systems)
 *
 * Deadline: August 2, 2026 (EU AI Act high-risk AI systems provisions)
 *
 * Compliance flow:
 *   1. Provider registers model with training data commitment hash
 *   2. Provider declares risk category (minimal/limited/high/unacceptable)
 *   3. Anyone can verify model compliance status before paying for inference
 *   4. Regulators/auditors can audit on-chain without accessing raw data
 *
 * Security fixes (v1.1):
 *   - EU_ACT_DEADLINE corrected to 2026-08-02 00:00:00 UTC (was wrong by 1 year)
 *   - Added 2-step ownership transfer
 *   - Added string length validation on model fields
 */
contract AIActCompliance {

    // ─────────────────────────────────────────────
    // ENUMS & STRUCTS
    // ─────────────────────────────────────────────

    enum RiskCategory {
        Unset,
        Minimal,        // e.g., spam filters, AI in video games
        Limited,        // e.g., chatbots (transparency obligation only)
        High,           // e.g., medical, HR, critical infrastructure
        Unacceptable    // banned: social scoring, real-time biometrics in public
    }

    enum ComplianceStatus {
        NotRegistered,
        Pending,        // committed but not yet audited
        Compliant,      // passed compliance check
        NonCompliant,   // failed compliance check
        Expired         // compliance certificate expired (annual renewal)
    }

    struct ModelRecord {
        bytes32 modelHash;              // keccak256 of model weights fingerprint
        string modelName;               // human-readable name
        string version;                 // semantic version
        address provider;               // deploying organization
        RiskCategory riskCategory;
        ComplianceStatus status;

        // Article 10 — Training Data
        bytes32 trainingDataHash;       // keccak256 commitment to training dataset manifest
        string trainingDataURI;         // IPFS/HTTPS URI of dataset card (public)
        uint256 datasetSizeBytes;       // approximate dataset size
        string[] dataCategories;        // e.g., ["text", "code", "synthetic"]
        bool containsPersonalData;      // triggers GDPR cross-check

        // Article 13 — Transparency
        string intendedPurpose;         // what the model is designed to do
        string[] limitations;           // known limitations, edge cases
        string humanOversightMeasures;  // how humans can override/override

        // Article 17 — Quality Management
        bytes32 evaluationHash;         // keccak256 of evaluation report
        uint256 registeredAt;
        uint256 lastAuditAt;
        uint256 expiresAt;              // compliance certificate expiry (1 year)
    }

    struct ComplianceAudit {
        bytes32 modelHash;
        address auditor;
        bool passed;
        string findings;                // IPFS URI of detailed findings
        uint256 auditedAt;
    }

    // ─────────────────────────────────────────────
    // STATE
    // ─────────────────────────────────────────────

    mapping(bytes32 => ModelRecord) public models;          // modelHash → record
    mapping(bytes32 => ComplianceAudit[]) public audits;    // modelHash → audit history
    mapping(address => bytes32[]) public providerModels;    // provider → model hashes
    mapping(address => bool) public approvedAuditors;       // authorized compliance auditors

    address public owner;
    address public pendingOwner;   // 2-step ownership transfer

    uint256 public constant COMPLIANCE_VALIDITY = 365 days;

    // FIXED: was 1754006400 (2025-08-01) — off by exactly 1 year
    // Correct value: 2026-08-02 00:00:00 UTC = 1785542400
    uint256 public constant EU_ACT_DEADLINE = 1785542400;   // 2026-08-02 00:00:00 UTC

    uint256 public totalModels;
    uint256 public constant VERSION = 2;

    uint256 private constant MAX_STRING_LEN = 1024;
    uint256 private constant MAX_SHORT_STRING_LEN = 256;

    // ─────────────────────────────────────────────
    // EVENTS
    // ─────────────────────────────────────────────

    event ModelRegistered(
        bytes32 indexed modelHash,
        address indexed provider,
        RiskCategory riskCategory,
        bytes32 trainingDataHash
    );

    event ComplianceAudited(
        bytes32 indexed modelHash,
        address indexed auditor,
        bool passed,
        uint256 expiresAt
    );

    event TrainingDataUpdated(bytes32 indexed modelHash, bytes32 newTrainingDataHash);
    event AuditorApproved(address indexed auditor);
    event AuditorRevoked(address indexed auditor);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ─────────────────────────────────────────────
    // ERRORS
    // ─────────────────────────────────────────────

    error NotOwner();
    error NotPendingOwner();
    error NotApprovedAuditor();
    error ModelAlreadyRegistered();
    error ModelNotFound();
    error UnacceptableRiskCategoryForbidden();
    error MissingTrainingDataForHighRisk();
    error NotModelProvider();
    error StringTooLong();
    error ZeroAddress();

    // ─────────────────────────────────────────────
    // CONSTRUCTOR
    // ─────────────────────────────────────────────

    constructor() {
        owner = msg.sender;
        approvedAuditors[msg.sender] = true; // owner is default auditor
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
    // MODEL REGISTRATION (Provider)
    // ─────────────────────────────────────────────

    /**
     * @notice Register a model with EU AI Act compliance data
     * @dev High-risk models (RiskCategory.High) MUST provide trainingDataHash
     */
    function registerModel(
        bytes32 modelHash,
        string calldata modelName,
        string calldata version,
        RiskCategory riskCategory,
        bytes32 trainingDataHash,
        string calldata trainingDataURI,
        uint256 datasetSizeBytes,
        string[] calldata dataCategories,
        bool containsPersonalData,
        string calldata intendedPurpose,
        string calldata humanOversightMeasures,
        bytes32 evaluationHash
    ) external {
        if (bytes(modelName).length > MAX_SHORT_STRING_LEN) revert StringTooLong();
        if (bytes(version).length > MAX_SHORT_STRING_LEN) revert StringTooLong();
        if (bytes(intendedPurpose).length > MAX_STRING_LEN) revert StringTooLong();
        if (models[modelHash].registeredAt != 0) revert ModelAlreadyRegistered();
        if (riskCategory == RiskCategory.Unacceptable) revert UnacceptableRiskCategoryForbidden();
        if (riskCategory == RiskCategory.High && trainingDataHash == bytes32(0)) {
            revert MissingTrainingDataForHighRisk();
        }

        models[modelHash] = ModelRecord({
            modelHash: modelHash,
            modelName: modelName,
            version: version,
            provider: msg.sender,
            riskCategory: riskCategory,
            status: ComplianceStatus.Pending,
            trainingDataHash: trainingDataHash,
            trainingDataURI: trainingDataURI,
            datasetSizeBytes: datasetSizeBytes,
            dataCategories: dataCategories,
            containsPersonalData: containsPersonalData,
            intendedPurpose: intendedPurpose,
            limitations: new string[](0),
            humanOversightMeasures: humanOversightMeasures,
            evaluationHash: evaluationHash,
            registeredAt: block.timestamp,
            lastAuditAt: 0,
            expiresAt: 0
        });

        providerModels[msg.sender].push(modelHash);
        totalModels++;

        emit ModelRegistered(modelHash, msg.sender, riskCategory, trainingDataHash);
    }

    /**
     * @notice Update training data commitment (e.g., after fine-tuning)
     */
    function updateTrainingData(
        bytes32 modelHash,
        bytes32 newTrainingDataHash,
        string calldata newTrainingDataURI
    ) external {
        ModelRecord storage record = models[modelHash];
        if (record.registeredAt == 0) revert ModelNotFound();
        if (record.provider != msg.sender) revert NotModelProvider();

        record.trainingDataHash = newTrainingDataHash;
        record.trainingDataURI = newTrainingDataURI;
        record.status = ComplianceStatus.Pending; // requires re-audit

        emit TrainingDataUpdated(modelHash, newTrainingDataHash);
    }

    // ─────────────────────────────────────────────
    // COMPLIANCE AUDITING (Approved Auditors)
    // ─────────────────────────────────────────────

    /**
     * @notice Submit audit result for a model
     */
    function auditModel(
        bytes32 modelHash,
        bool passed,
        string calldata findingsURI
    ) external {
        if (bytes(findingsURI).length > MAX_STRING_LEN) revert StringTooLong();
        if (!approvedAuditors[msg.sender]) revert NotApprovedAuditor();
        ModelRecord storage record = models[modelHash];
        if (record.registeredAt == 0) revert ModelNotFound();

        record.status = passed ? ComplianceStatus.Compliant : ComplianceStatus.NonCompliant;
        record.lastAuditAt = block.timestamp;
        record.expiresAt = passed ? block.timestamp + COMPLIANCE_VALIDITY : 0;

        audits[modelHash].push(ComplianceAudit({
            modelHash: modelHash,
            auditor: msg.sender,
            passed: passed,
            findings: findingsURI,
            auditedAt: block.timestamp
        }));

        emit ComplianceAudited(modelHash, msg.sender, passed, record.expiresAt);
    }

    // ─────────────────────────────────────────────
    // VERIFICATION (Public Read)
    // ─────────────────────────────────────────────

    /**
     * @notice Check if a model is currently EU AI Act compliant
     */
    function checkCompliance(bytes32 modelHash)
        external
        view
        returns (bool compliant, ModelRecord memory record)
    {
        record = models[modelHash];
        if (record.registeredAt == 0) return (false, record);

        compliant = (
            record.status == ComplianceStatus.Compliant &&
            record.expiresAt > block.timestamp
        );
    }

    /**
     * @notice Get compliance summary (gas-efficient)
     */
    function getComplianceStatus(bytes32 modelHash)
        external
        view
        returns (
            ComplianceStatus status,
            RiskCategory riskCategory,
            uint256 expiresAt,
            bool deadlineCompliant
        )
    {
        ModelRecord storage record = models[modelHash];
        status = record.status;
        riskCategory = record.riskCategory;
        expiresAt = record.expiresAt;
        // Was the model registered before the EU AI Act deadline (2026-08-02)?
        deadlineCompliant = record.registeredAt > 0 && record.registeredAt <= EU_ACT_DEADLINE;
    }

    /**
     * @notice Get all models registered by a provider
     */
    function getProviderModels(address provider) external view returns (bytes32[] memory) {
        return providerModels[provider];
    }

    /**
     * @notice Get audit history for a model
     */
    function getAuditHistory(bytes32 modelHash) external view returns (ComplianceAudit[] memory) {
        return audits[modelHash];
    }

    // ─────────────────────────────────────────────
    // ADMIN
    // ─────────────────────────────────────────────

    function approveAuditor(address auditor) external {
        if (msg.sender != owner) revert NotOwner();
        approvedAuditors[auditor] = true;
        emit AuditorApproved(auditor);
    }

    function revokeAuditor(address auditor) external {
        if (msg.sender != owner) revert NotOwner();
        approvedAuditors[auditor] = false;
        emit AuditorRevoked(auditor);
    }
}
