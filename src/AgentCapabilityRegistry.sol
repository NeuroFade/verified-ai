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
 * An "agent" here is any autonomous software entity that:
 *   - Has an Ethereum address
 *   - Declares capabilities (skills, models, APIs)
 *   - Optionally links to Verified AI attestations for its inference calls
 *
 * Compatible with ERC-8004 agent identity standard.
 * See: https://eips.ethereum.org/EIPS/eip-8004 (pending)
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
    mapping(address => address[]) public trustedBy;                        // who trusts this agent
    mapping(address => address[]) public trusts;                           // who this agent trusts

    // Attestation registry link (optional — for reputation tracking)
    address public attestationRegistry;
    address public owner;

    uint256 public totalAgents;
    uint256 public constant VERSION = 1;

    // ERC-8004 compatibility fields
    string public constant ERC8004_VERSION = "0.1.0";
    bytes4 public constant ERC8004_INTERFACE_ID = 0x8004_0000; // placeholder

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

    // ─────────────────────────────────────────────
    // ERRORS
    // ─────────────────────────────────────────────

    error NotOwner();
    error NotAgentOwner();
    error AgentAlreadyRegistered();
    error AgentNotFound();
    error CapabilityAlreadyExists();
    error CapabilityNotFound();
    error InvalidTrustLevel();
    error ZeroAddress();

    // ─────────────────────────────────────────────
    // CONSTRUCTOR
    // ─────────────────────────────────────────────

    constructor(address _attestationRegistry) {
        if (_attestationRegistry == address(0)) revert ZeroAddress();
        owner = msg.sender;
        attestationRegistry = _attestationRegistry;
    }

    // ─────────────────────────────────────────────
    // AGENT REGISTRATION
    // ─────────────────────────────────────────────

    /**
     * @notice Register an AI agent with its identity and metadata
     * @param agentAddress The agent's Ethereum address (can be a smart wallet)
     * @param name Human-readable agent name
     * @param description What this agent does
     * @param metadataURI IPFS URI of full agent specification (ERC-8004 format)
     */
    function registerAgent(
        address agentAddress,
        string calldata name,
        string calldata description,
        string calldata metadataURI
    ) external {
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
     * @param agentAddress The agent to add capability to
     * @param capabilityId Unique slug (e.g., "inference:llama3-70b")
     * @param name Human-readable capability name
     * @param description What this capability does
     * @param capType Capability category
     * @param modelIds Model identifiers used (can be empty)
     * @param endpointURI API endpoint URI (can be empty for privacy)
     * @param x402Enabled Whether this capability accepts x402 payments
     * @param pricePerCallWei Price in wei (0 = free)
     * @param attestationRequired Whether calls must be attested on Verified AI
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
     * @param toAgent Agent to trust
     * @param trustLevel 1–100 (100 = full trust)
     * @param reason Human-readable reason for trust
     */
    function grantTrust(
        address toAgent,
        uint256 trustLevel,
        string calldata reason
    ) external {
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

        trustedBy[toAgent].push(msg.sender);
        trusts[msg.sender].push(toAgent);

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
     * @param agentAddress Agent to update
     * @param delta Signed delta in basis points (positive = reputation up)
     * @param attestationsAdded Number of new verified attestations
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

    /**
     * @notice Get all capability IDs for an agent
     */
    function getAgentCapabilities(address agentAddress)
        external
        view
        returns (string[] memory)
    {
        return agentCapabilityIds[agentAddress];
    }

    /**
     * @notice Get a specific capability for an agent
     */
    function getCapability(address agentAddress, string calldata capabilityId)
        external
        view
        returns (Capability memory)
    {
        return capabilities[agentAddress][capabilityId];
    }

    /**
     * @notice Get agents that trust this agent
     */
    function getEndorsers(address agentAddress) external view returns (address[] memory) {
        return trustedBy[agentAddress];
    }

    /**
     * @notice Check if agent A trusts agent B (and at what level)
     */
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
