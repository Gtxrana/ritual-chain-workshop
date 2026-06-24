// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract CommitRevealBounty {

    struct Bounty {
        address creator;
        string  question;
        uint256 reward;
        uint256 submissionDeadline;
        uint256 revealDeadline;
        bool    finalized;
        uint256 winnerIndex;
    }

    struct Commitment {
        bytes32 commitHash;
        bool    committed;
        bool    revealed;
        string  answer;
    }

    uint256 public bountyCount;
    mapping(uint256 => Bounty) public bounties;
    mapping(uint256 => mapping(address => Commitment)) public commitments;
    mapping(uint256 => address[]) public revealedParticipants;

    event BountyCreated(uint256 indexed bountyId, address creator, uint256 reward);
    event CommitmentSubmitted(uint256 indexed bountyId, address indexed participant);
    event AnswerRevealed(uint256 indexed bountyId, address indexed participant);
    event JudgingRequested(uint256 indexed bountyId, uint256 revealedCount);
    event WinnerFinalized(uint256 indexed bountyId, address winner, uint256 reward);

    modifier bountyExists(uint256 bountyId) {
        require(bountyId < bountyCount, "Bounty does not exist");
        _;
    }

    modifier onlyCreator(uint256 bountyId) {
        require(msg.sender == bounties[bountyId].creator, "Not bounty creator");
        _;
    }

    modifier notFinalized(uint256 bountyId) {
        require(!bounties[bountyId].finalized, "Bounty already finalized");
        _;
    }

    function createBounty(
        string  calldata question,
        uint256 submissionDeadline,
        uint256 revealDeadline
    ) external payable returns (uint256 bountyId) {
        require(msg.value > 0,                         "Reward must be > 0");
        require(submissionDeadline > block.timestamp,  "Submission deadline in the past");
        require(revealDeadline > submissionDeadline,   "Reveal deadline must be after submission deadline");

        bountyId = bountyCount++;
        bounties[bountyId] = Bounty({
            creator:            msg.sender,
            question:           question,
            reward:             msg.value,
            submissionDeadline: submissionDeadline,
            revealDeadline:     revealDeadline,
            finalized:          false,
            winnerIndex:        0
        });

        emit BountyCreated(bountyId, msg.sender, msg.value);
    }

    function submitCommitment(
        uint256 bountyId,
        bytes32 commitment
    )
        external
        bountyExists(bountyId)
        notFinalized(bountyId)
    {
        Bounty storage b = bounties[bountyId];
        require(block.timestamp <= b.submissionDeadline, "Submission phase has ended");
        require(commitment != bytes32(0),                "Commitment cannot be zero");

        Commitment storage c = commitments[bountyId][msg.sender];
        require(!c.committed, "Already committed");

        c.commitHash = commitment;
        c.committed  = true;

        emit CommitmentSubmitted(bountyId, msg.sender);
    }

    function revealAnswer(
        uint256          bountyId,
        string  calldata answer,
        bytes32          salt
    )
        external
        bountyExists(bountyId)
        notFinalized(bountyId)
    {
        Bounty storage b = bounties[bountyId];
        require(block.timestamp >  b.submissionDeadline, "Submission phase still active");
        require(block.timestamp <= b.revealDeadline,     "Reveal phase has ended");
        require(bytes(answer).length > 0,                "Answer cannot be empty");

        Commitment storage c = commitments[bountyId][msg.sender];
        require(c.committed,  "No commitment found");
        require(!c.revealed,  "Already revealed");

        bytes32 expected = keccak256(
            abi.encodePacked(answer, salt, msg.sender, bountyId)
        );
        require(expected == c.commitHash, "Hash mismatch — reveal failed");

        c.revealed = true;
        c.answer   = answer;

        revealedParticipants[bountyId].push(msg.sender);

        emit AnswerRevealed(bountyId, msg.sender);
    }

    function judgeAll(
        uint256        bountyId,
        bytes calldata llmInput
    )
        external
        bountyExists(bountyId)
        notFinalized(bountyId)
        onlyCreator(bountyId)
    {
        Bounty storage b = bounties[bountyId];
        require(block.timestamp > b.revealDeadline, "Reveal phase still active");

        uint256 count = revealedParticipants[bountyId].length;
        require(count > 0, "No revealed answers to judge");

        emit JudgingRequested(bountyId, count);
        (llmInput);
    }

    function finalizeWinner(
        uint256 bountyId,
        uint256 winnerIndex
    )
        external
        bountyExists(bountyId)
        notFinalized(bountyId)
        onlyCreator(bountyId)
    {
        Bounty storage b = bounties[bountyId];
        require(block.timestamp > b.revealDeadline, "Reveal phase still active");

        address[] storage participants = revealedParticipants[bountyId];
        require(winnerIndex < participants.length, "Invalid winner index");

        b.finalized   = true;
        b.winnerIndex = winnerIndex;

        address winner = participants[winnerIndex];
        uint256 reward = b.reward;

        (bool success, ) = payable(winner).call{value: reward}("");
        require(success, "Reward transfer failed");

        emit WinnerFinalized(bountyId, winner, reward);
    }

    function getRevealedAnswers(uint256 bountyId)
        external
        view
        bountyExists(bountyId)
        returns (address[] memory participants, string[] memory answers)
    {
        address[] storage rp = revealedParticipants[bountyId];
        uint256 len = rp.length;
        participants = new address[](len);
        answers      = new string[](len);
        for (uint256 i = 0; i < len; i++) {
            participants[i] = rp[i];
            answers[i]      = commitments[bountyId][rp[i]].answer;
        }
    }

    function computeCommitment(
        string  calldata answer,
        bytes32          salt,
        address          participant,
        uint256          bountyId
    ) external pure returns (bytes32) {
        return keccak256(abi.encodePacked(answer, salt, participant, bountyId));
    }

    function revealedCount(uint256 bountyId) external view returns (uint256) {
        return revealedParticipants[bountyId].length;
    }
}
