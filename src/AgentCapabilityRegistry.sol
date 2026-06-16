// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title AgentCapabilityRegistry
 * @notice Agent capability registry for Verified AI — extends ERC-8004
 * @dev ERC-8004 (Trustless Agents) defines on-chain agent identity.
 *      This contract extends it with:
 *      - Capability declarations (what the agent can do)
 *      - Verified inference endpoints (linked to AttestationRegistry)
 *      - Reputation scores (based on attestation volume + quality)
 *      - Agent-to-agent trust delegation
 *
 * Security fixes (v1.1):
 *   - grantTrust() now checks for duplicate trust links to prevent array bloat DoS
 *   - Removed placeholder ERC8004_INTERFACE_ID (was invalid bytes4 literal)
 *   - Added 2-step ownership transfer
 *   - Added string length validation
 */
contract AgentCapabilityRegistry {

    // ─────────────────────────────────────────────
    // STRUCTS
    // ─────────────────────────────────────────────

    struct AgentProfile {
        address agentAddress;
        string name;
        string description;
        string metadataURI;         // IPFS URI: full agent spec (ERC-8004 compatible)
        address owner;              // EOA that controls this agent
        uint256 registeredAt;
        uint256 lastActiveAt;
        bool active;
        uint256 reputationScore;    // 0–10000 (basis points, updated by registry)
        uint256 totalAttestations;  // count of verified inference calls
    }

    struct Capability {
        string capabilityId;        // unique slug: "inference:llama3", "tool:web-search"
        string name;
        string description;
        CapabilityType capType;
        string[] modelIds;          // model hashes or identifiers this cap uses
        string endpointURI;         // API endpoint (optional, can be private)
        bool x402Enabled;           // accepts x402 micropayments
        uint256 pricePerCallWei;    // price in wei if x402Enabled (0 = free)
        bool attestationRequired;   // all calls to this cap must be attested
        bool active;
        uint256 addedAt;
    }

    enum CapabilityType {
        Inference,      // AI model inference
        Tool,           // External tool/API
        Workflow,       // Multi-step agent workflow
        DataSource,     // Data provider
        Verification,   // Verification/audit service
        Other
    }

    struct TrustLink {
        address from;           // trusting agent
        address to;             // trusted agent
        uint256 trustLevel;     // 1–100
        string reason;          // why this trust was granted
        uint256 createdAt;
        bool active;
    }

    // ─────────────────────────────────────────────
    // STATE
    // ─────────────────────────────────────────────

    mapping(address => AgentProfile) public agents;
    mapping(address => mapping(string => Capability)) public capabilities; // agent → capId → cap
    mapping(address => string[]) public agentCapabilityIds;               // agent → list of capIds
    mapping(address => mapping(address => TrustLink)) public trustLinks;  // from → to → link

    // Track whether a trust link already exists to prevent duplicate array entries
    mapping(address => mapping(address => bool)) private _trustLinkExists;

    mapping(address => address[]) public trustedBy;  // who trusts this agent
    mapping(address => address[]) public trusts;     // who this agent trusts

    // Attestation registry link (optional — for reputation tracking)
    address public attestationRegistry;
    address public owner;
    address public pendingOwner;  // 2-step ownership transfer

    uint256 public totalAgents;
    uint256 public constant VERSION = 2;

    // ERC-8004 compatibility
    string public constant ERC8004_VERSION = "0.1.0";
    // NOTE: ERC8004_INTERFACE_ID intentionally omitted until standard is finalized

    uint256 private constant MAX_STRING_LEN = 512;
    uint256 private constant MAX_SHORT_STRING_LEN = 256;

    // ─────────────────────────────────────────────
    // EVENTS
    // ─────────────────────────────────────────────

    event AgentRegistered(
        address indexed agentAddress,
        address indexed owner,
        string name,
        string metadataURI
    );

    event CapabilityAdded(
        address indexed agentAddress,
        string capabilityId,
        CapabilityType capType,
        bool x402Enabled
    );

    event CapabilityUpdated(address indexed agentAddress, string capabilityId);
    event CapabilityDeactivated(address indexed agentAddress, string capabilityId);

    event TrustGranted(address indexed from, address indexed to, uint256 trustLevel);
    event TrustRevoked(address indexed from, address indexed to);

    event ReputationUpdated(address indexed agentAddress, uint256 newScore);
    event AgentDeactivated(address indexed agentAddress);
    event OwnershipTransferStarted(address indexed previousOwner, address indexed newOwner);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // ─────────────────────────────────────────────
    // ERRORS
    // ─────────────────────────────────────────────

    error NotOwner();
    error NotPendingOwner();
    error NotAgentOwner();
    error AgentAlreadyRegistered();
    error AgentNotFound();
    error CapabilityAlreadyExists();
    error CapabilityNotFound();
    error InvalidTrustLevel();
    error ZeroAddress();
    error StringTooLong();

    // ─────────────────────────────────────────────
    // CONSTRUCTOR
    // ─────────────────────────────────────────────

    constructor(address _attestationRegistry) {
        if (_attestationRegistry == address(0)) revert ZeroAddress();
        owner = msg.sender;
        attestationRegistry = _attestationRegistry;
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
    // AGENT REGISTRATION
    // ─────────────────────────────────────────────

    /**
     * @notice Register an AI agent with its identity and metadata
     */
    function registerAgent(
        address agentAddress,
        string calldata name,
        string calldata description,
        string calldata metadataURI
    ) external {
        if (bytes(name).length > MAX_SHORT_STRING_LEN) revert StringTooLong();
        if (bytes(description).length > MAX_STRING_LEN) revert StringTooLong();
        if (agents[agentAddress].registeredAt != 0) revert AgentAlreadyRegistered();

        agents[agentAddress] = AgentProfile({
            agentAddress: agentAddress,
            name: name,
            description: description,
            metadataURI: metadataURI,
            owner: msg.sender,
            registeredAt: block.timestamp,
            lastActiveAt: block.timestamp,
            active: true,
            reputationScore: 5000, // start at 50/100
            totalAttestations: 0
        });

        totalAgents++;

        emit AgentRegistered(agentAddress, msg.sender, name, metadataURI);
    }

    // ─────────────────────────────────────────────
    // CAPABILITY MANAGEMENT
    // ─────────────────────────────────────────────

    /**
     * @notice Add a capability to an agent's profile
     */
    function addCapability(
        address agentAddress,
        string calldata capabilityId,
        string calldata name,
        string calldata description,
        CapabilityType capType,
        string[] calldata modelIds,
        string calldata endpointURI,
        bool x402Enabled,
        uint256 pricePerCallWei,
        bool attestationRequired
    ) external {
        if (bytes(name).length > MAX_SHORT_STRING_LEN) revert StringTooLong();
        if (bytes(description).length > MAX_STRING_LEN) revert StringTooLong();

        AgentProfile storage agent = agents[agentAddress];
        if (agent.registeredAt == 0) revert AgentNotFound();
        if (agent.owner != msg.sender) revert NotAgentOwner();
        if (capabilities[agentAddress][capabilityId].addedAt != 0) revert CapabilityAlreadyExists();

        capabilities[agentAddress][capabilityId] = Capability({
            capabilityId: capabilityId,
            name: name,
            description: description,
            capType: capType,
            modelIds: modelIds,
            endpointURI: endpointURI,
            x402Enabled: x402Enabled,
            pricePerCallWei: pricePerCallWei,
            attestationRequired: attestationRequired,
            active: true,
            addedAt: block.timestamp
        });

        agentCapabilityIds[agentAddress].push(capabilityId);

        emit CapabilityAdded(agentAddress, capabilityId, capType, x402Enabled);
    }

    /**
     * @notice Deactivate a capability
     */
    function deactivateCapability(address agentAddress, string calldata capabilityId) external {
        AgentProfile storage agent = agents[agentAddress];
        if (agent.owner != msg.sender) revert NotAgentOwner();
        Capability storage cap = capabilities[agentAddress][capabilityId];
        if (cap.addedAt == 0) revert CapabilityNotFound();
        cap.active = false;
        emit CapabilityDeactivated(agentAddress, capabilityId);
    }

    // ─────────────────────────────────────────────
    // TRUST SYSTEM
    // ─────────────────────────────────────────────

    /**
     * @notice Grant trust to another agent
     * @dev Prevents duplicate array entries — re-calling updates the existing link
     */
    function grantTrust(
        address toAgent,
        uint256 trustLevel,
        string calldata reason
    ) external {
        if (bytes(reason).length > MAX_STRING_LEN) revert StringTooLong();
        if (trustLevel == 0 || trustLevel > 100) revert InvalidTrustLevel();
        if (agents[toAgent].registeredAt == 0) revert AgentNotFound();

        trustLinks[msg.sender][toAgent] = TrustLink({
            from: msg.sender,
            to: toAgent,
            trustLevel: trustLevel,
            reason: reason,
            createdAt: block.timestamp,
            active: true
        });

        // Only push to arrays if this is a NEW trust link (prevents DoS via array bloat)
        if (!_trustLinkExists[msg.sender][toAgent]) {
            _trustLinkExists[msg.sender][toAgent] = true;
            trustedBy[toAgent].push(msg.sender);
            trusts[msg.sender].push(toAgent);
        }

        emit TrustGranted(msg.sender, toAgent, trustLevel);
    }

    /**
     * @notice Revoke trust from an agent
     */
    function revokeTrust(address toAgent) external {
        TrustLink storage link = trustLinks[msg.sender][toAgent];
        require(link.createdAt != 0, "No trust link exists");
        link.active = false;
        emit TrustRevoked(msg.sender, toAgent);
    }

    // ─────────────────────────────────────────────
    // REPUTATION
    // ─────────────────────────────────────────────

    /**
     * @notice Update agent reputation (called by registry owner or attestation contract)
     */
    function updateReputation(
        address agentAddress,
        int256 delta,
        uint256 attestationsAdded
    ) external {
        if (msg.sender != owner && msg.sender != attestationRegistry) revert NotOwner();

        AgentProfile storage agent = agents[agentAddress];
        if (agent.registeredAt == 0) revert AgentNotFound();

        if (delta >= 0) {
            uint256 newScore = agent.reputationScore + uint256(delta);
            agent.reputationScore = newScore > 10000 ? 10000 : newScore;
        } else {
            uint256 decrease = uint256(-delta);
            agent.reputationScore = agent.reputationScore > decrease
                ? agent.reputationScore - decrease
                : 0;
        }

        agent.totalAttestations += attestationsAdded;
        agent.lastActiveAt = block.timestamp;

        emit ReputationUpdated(agentAddress, agent.reputationScore);
    }

    // ─────────────────────────────────────────────
    // READ
    // ─────────────────────────────────────────────

    function getAgentCapabilities(address agentAddress)
        external
        view
        returns (string[] memory)
    {
        return agentCapabilityIds[agentAddress];
    }

    function getCapability(address agentAddress, string calldata capabilityId)
        external
        view
        returns (Capability memory)
    {
        return capabilities[agentAddress][capabilityId];
    }

    function getEndorsers(address agentAddress) external view returns (address[] memory) {
        return trustedBy[agentAddress];
    }

    function getTrustLevel(address from, address to)
        external
        view
        returns (bool exists, uint256 level)
    {
        TrustLink storage link = trustLinks[from][to];
        exists = link.active;
        level = link.trustLevel;
    }

    /**
     * @notice ERC-8004 compatible: get agent metadata URI
     */
    function agentURI(address agentAddress) external view returns (string memory) {
        return agents[agentAddress].metadataURI;
    }
}
