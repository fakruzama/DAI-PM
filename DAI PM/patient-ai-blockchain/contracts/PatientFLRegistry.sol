// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/**
 * Patient-controlled federated learning coordinator.
 * - Patients grant consent per model/task.
 * - FL rounds defined with DP parameters, participant caps.
 * - Secure aggregation via commit-reveal metadata (off-chain MPC).
 * - Committee consensus to finalize model artifact.
 * Notes:
 * - No PII on-chain. Use hashed patientId and anonymized clientId.
 */
contract PatientFLRegistry {
    struct Consent {
        bool allowed;
        uint256 grantedAt;
        string scope; // e.g., "diabetes_risk_v1"
    }

    struct Round {
        bytes32 taskId;
        uint256 roundIndex;
        uint256 startAt;
        uint256 endAt;
        uint256 maxParticipants;
        uint256 epsilon;
        uint256 delta;
        bool closed;
        bytes32 modelHash;
    }

    struct Participant {
        address client;
        bytes32 commitHash;
        bool revealed;
    }

    struct CommitteeVote {
        address voter;
        bytes32 modelHash;
    }

    // patientId => taskId => Consent
    mapping(bytes32 => mapping(bytes32 => Consent)) public consent;

    // taskId => latest round index
    mapping(bytes32 => uint256) public latestRoundIndex;

    // taskId => roundIndex => Round
    mapping(bytes32 => mapping(uint256 => Round)) public rounds;

    // taskId => roundIndex => participants
    mapping(bytes32 => mapping(uint256 => Participant[])) public participantsByRound;

    // taskId => roundIndex => committee voters
    mapping(bytes32 => mapping(uint256 => CommitteeVote[])) public votesByRound;

    // committee membership (simple PoA)
    mapping(address => bool) public committee;

    event ConsentGranted(bytes32 indexed patientId, bytes32 indexed taskId, string scope);
    event ConsentRevoked(bytes32 indexed patientId, bytes32 indexed taskId);
    event RoundOpened(bytes32 indexed taskId, uint256 indexed roundIndex, uint256 epsilon, uint256 delta, uint256 cap);
    event UpdateCommitted(bytes32 indexed taskId, uint256 indexed roundIndex, address client, bytes32 commitHash);
    event UpdateRevealed(bytes32 indexed taskId, uint256 indexed roundIndex, address client, bytes32 revealHash);
    event RoundClosed(bytes32 indexed taskId, uint256 indexed roundIndex);
    event CommitteeMemberAdded(address indexed member);
    event CommitteeMemberRemoved(address indexed member);
    event CommitteeVoted(bytes32 indexed taskId, uint256 indexed roundIndex, address voter, bytes32 modelHash);
    event ModelFinalized(bytes32 indexed taskId, uint256 indexed roundIndex, bytes32 modelHash);

    modifier onlyCommittee() {
        require(committee[msg.sender], "not committee");
        _;
    }

    constructor(address[] memory initialCommittee) {
        for (uint256 i = 0; i < initialCommittee.length; i++) {
            committee[initialCommittee[i]] = true;
            emit CommitteeMemberAdded(initialCommittee[i]);
        }
    }

    // Patients manage consent per task
    function grantConsent(bytes32 patientId, bytes32 taskId, string calldata scope) external {
        consent[patientId][taskId] = Consent(true, block.timestamp, scope);
        emit ConsentGranted(patientId, taskId, scope);
    }

    function revokeConsent(bytes32 patientId, bytes32 taskId) external {
        consent[patientId][taskId] = Consent(false, block.timestamp, "");
        emit ConsentRevoked(patientId, taskId);
    }

    // Open a new FL round with DP policy
    function openRound(bytes32 taskId, uint256 epsilon, uint256 delta, uint256 maxParticipants) external onlyCommittee {
        uint256 idx = latestRoundIndex[taskId] + 1;
        latestRoundIndex[taskId] = idx;
        rounds[taskId][idx] = Round({
            taskId: taskId,
            roundIndex: idx,
            startAt: block.timestamp,
            endAt: 0,
            maxParticipants: maxParticipants,
            epsilon: epsilon,
            delta: delta,
            closed: false,
            modelHash: bytes32(0)
        });
        emit RoundOpened(taskId, idx, epsilon, delta, maxParticipants);
    }

    // Clients commit their masked updates (commit phase)
    function commitUpdate(bytes32 taskId, uint256 roundIndex, bytes32 commitHash) external {
        Round storage r = rounds[taskId][roundIndex];
        require(!r.closed, "round closed");
        Participant[] storage plist = participantsByRound[taskId][roundIndex];
        require(plist.length < r.maxParticipants, "cap reached");

        plist.push(Participant({
            client: msg.sender,
            commitHash: commitHash,
            revealed: false
        }));
        emit UpdateCommitted(taskId, roundIndex, msg.sender, commitHash);
    }

    // Clients reveal metadata (e.g., mask shares pointers) for secure aggregation (reveal phase)
    function revealUpdate(bytes32 taskId, uint256 roundIndex, bytes32 commitHash, bytes32 revealHash) external {
        Participant[] storage plist = participantsByRound[taskId][roundIndex];
        bool matched = false;
        for (uint256 i = 0; i < plist.length; i++) {
            if (plist[i].client == msg.sender && plist[i].commitHash == commitHash && !plist[i].revealed) {
                plist[i].revealed = true;
                matched = true;
                break;
            }
        }
        require(matched, "no matching commit");
        emit UpdateRevealed(taskId, roundIndex, msg.sender, revealHash);
    }

    // Close round (after off-chain secure aggregation completes)
    function closeRound(bytes32 taskId, uint256 roundIndex) external onlyCommittee {
        Round storage r = rounds[taskId][roundIndex];
        require(!r.closed, "already closed");
        r.closed = true;
        r.endAt = block.timestamp;
        emit RoundClosed(taskId, roundIndex);
    }

    // Committee voting to finalize the model artifact (e.g., IPFS CID hash)
    function voteFinalize(bytes32 taskId, uint256 roundIndex, bytes32 modelHash) external onlyCommittee {
        votesByRound[taskId][roundIndex].push(CommitteeVote({
            voter: msg.sender,
            modelHash: modelHash
        }));
        emit CommitteeVoted(taskId, roundIndex, msg.sender, modelHash);
    }

    // Simple majority consensus: pick most-voted modelHash; set as finalized
    function finalizeModel(bytes32 taskId, uint256 roundIndex) external onlyCommittee {
        Round storage r = rounds[taskId][roundIndex];
        require(r.closed, "round not closed");
        CommitteeVote[] storage votes = votesByRound[taskId][roundIndex];
        require(votes.length > 0, "no votes");

        bytes32 winner = votes[0].modelHash;
        uint256 bestCount = 0;
        for (uint256 i = 0; i < votes.length; i++) {
            uint256 count = 0;
            for (uint256 j = 0; j < votes.length; j++) {
                if (votes[j].modelHash == votes[i].modelHash) count++;
            }
            if (count > bestCount) { bestCount = count; winner = votes[i].modelHash; }
        }

        r.modelHash = winner;
        emit ModelFinalized(taskId, roundIndex, winner);
    }

    // Read helpers
    function getRound(bytes32 taskId, uint256 roundIndex) external view returns (Round memory) {
        return rounds[taskId][roundIndex];
    }

    function listParticipants(bytes32 taskId, uint256 roundIndex) external view returns (Participant[] memory) {
        return participantsByRound[taskId][roundIndex];
    }

    // Committee management
    function addCommittee(address member) external onlyCommittee {
        committee[member] = true;
        emit CommitteeMemberAdded(member);
    }

    function removeCommittee(address member) external onlyCommittee {
        committee[member] = false;
        emit CommitteeMemberRemoved(member);
    }
}
