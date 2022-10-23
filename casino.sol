//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.12;

contract Casino {
    uint256 constant MIN_VALUE = 0.001 ether;
    uint256 betIds;
    mapping(uint256 => Proposal) betIdToProposal;
    mapping(address => uint256) fundsBalance;

    struct Proposal {
        uint256 value;
        uint256 betStopBlock;
        uint256 judgeStartBlock;
        address[] gamblers;
        uint256[] commitments;
        string[] reveals;
        uint256 numOfReveals;
    }

    event BetProposed(
        uint256 indexed betId,
        uint256 value,
        uint256 betStopBlock,
        uint256 judgeStartBlock
    );

    event BetAccepted(uint256 indexed betId, address indexed sideB);

    event BetSettled(
        uint256 indexed betId,
        address winner,
        address loser,
        uint256 value
    );

    function proposeBet(
        uint256 _commitment,
        uint256 _blocksForBet,
        uint256 _blocksForReveal
    ) external payable {
        require(msg.value >= MIN_VALUE, "Too smaller value for bet");

        Proposal storage proposedBet = betIdToProposal[betIds];
        proposedBet.gamblers = new address[](2);
        proposedBet.commitments = new uint256[](2);
        proposedBet.reveals = new string[](2);

        proposedBet.value = msg.value;
        proposedBet.betStopBlock = block.number + _blocksForBet;
        proposedBet.judgeStartBlock =
            proposedBet.betStopBlock +
            _blocksForReveal;
        proposedBet.gamblers[0] = msg.sender;
        proposedBet.commitments[0] = _commitment;

        emit BetProposed(
            betIds,
            msg.value,
            proposedBet.betStopBlock,
            proposedBet.judgeStartBlock
        );
        betIds++;
    }

    function cancelBet(uint256 betId) public {
        Proposal memory proposedBet = betIdToProposal[betId];
        require(proposedBet.gamblers[0] == msg.sender, "Not your bet");
        require(
            proposedBet.gamblers[1] == address(0),
            "Can't cancel bet already be accepted"
        );

        fundsBalance[msg.sender] += proposedBet.value;
        clearProposal(betId);
    }

    function acceptBet(uint256 betId, uint256 _commitment) external payable {
        Proposal storage proposedBet = betIdToProposal[betId];
        require(
            msg.value == proposedBet.value,
            "Need to bet the same amount as sideA"
        );
        require(block.number < proposedBet.betStopBlock, "Time's up!");
        require(proposedBet.gamblers[1] == address(0), "Already accepted!");

        proposedBet.gamblers[1] = msg.sender;
        proposedBet.commitments[1] = _commitment;
        emit BetAccepted(betId, msg.sender);
    }

    function modifyBet(
        uint256 betId,
        uint256 side,
        uint256 _commitment
    ) public {
        Proposal storage proposedBet = betIdToProposal[betId];
        require(
            proposedBet.gamblers[side] == msg.sender,
            "Not the gambler on this side"
        );
        require(block.number < proposedBet.betStopBlock, "Time's up!");

        proposedBet.commitments[side] = _commitment;
    }

    function revealBet(
        uint256 betId,
        uint256 side,
        string memory _reveal
    ) external {
        Proposal storage proposedBet = betIdToProposal[betId];
        require(
            block.number > proposedBet.betStopBlock,
            "Don't show your reveal before bet stop!"
        );
        uint256 _commitment = uint256(keccak256(abi.encodePacked(_reveal)));
        require(proposedBet.commitments[side] == _commitment, "Wrong reveal!");

        proposedBet.reveals[side] = _reveal;
        proposedBet.numOfReveals++;
    }

    function judge(uint256 betId) public {
        Proposal storage proposedBet = betIdToProposal[betId];
        address sideB = proposedBet.gamblers[1];
        require(sideB != address(0), "!");

        uint256 _numOfReveals = proposedBet.numOfReveals;
        uint256 _value = proposedBet.value;
        address sideA = proposedBet.gamblers[0];

        if (_numOfReveals < 2) {
            require(
                block.number > proposedBet.judgeStartBlock,
                "Time's not up!"
            );
            if (_numOfReveals == 0) {
                uint256 judgeFee = (_value * 2 * 5) / 100;
                uint256 aveVal = _value - judgeFee / 2;
                fundsBalance[sideA] += aveVal;
                fundsBalance[sideB] += aveVal;
                fundsBalance[msg.sender] += judgeFee;
            } else {
                if (bytes(proposedBet.reveals[1]).length == 0) {
                    fundsBalance[sideA] += _value * 2;
                } else fundsBalance[sideB] += _value * 2;
            }
        } else {
            string memory _str = string.concat(
                proposedBet.reveals[0],
                proposedBet.reveals[1]
            );
            uint256 result = uint256(keccak256(abi.encodePacked(_str)));
            if (result % 2 == 0) {
                fundsBalance[sideA] += _value * 2;
                emit BetSettled(betId, sideA, sideB, _value);
            } else fundsBalance[sideB] += _value * 2;
            emit BetSettled(betId, sideB, sideA, _value);
        }
        clearProposal(betId);
    }

    function clearProposal(uint256 betId) internal {
        delete betIdToProposal[betId];
        betIds--;
        betIdToProposal[betId] = betIdToProposal[betIds];
    }

    function withdrawFunds() public {
        uint256 transAmount = fundsBalance[msg.sender];
        require(transAmount > 0, "No balance can be withdrawn.");
        fundsBalance[msg.sender] = 0;
        payable(msg.sender).transfer(transAmount);
    }

    // -------------------------------getter---------------------------------------

    function getAllBets() public view returns (Proposal[] memory) {
        Proposal[] memory proposedBets = new Proposal[](betIds);
        for (uint256 i = 0; i < betIds; i++) {
            proposedBets[i] = betIdToProposal[i];
        }
        return proposedBets;
    }

    function getBetIds() public view returns (uint256) {
        return betIds;
    }

    function getProposal(uint256 betId) public view returns (Proposal memory) {
        return betIdToProposal[betId];
    }

    function getFundsBalance(address gambler) public view returns (uint256) {
        return fundsBalance[gambler];
    }

    function getMinValue() public pure returns (uint256) {
        return MIN_VALUE;
    }
}
