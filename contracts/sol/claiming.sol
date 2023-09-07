// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface PairedInterface {
    function updateActiveSupply(uint256 amount) external;
}

contract Claiming is ReentrancyGuard, Ownable {
    IERC20 pairedToken;
    PairedInterface paired;
    address public _admin;

    bytes32 public _whitelist;
    mapping (address => uint256) public _claimed;

    event NewRoundIssues(uint256 claimableTotal);

    constructor(address _pairedToken) {
        pairedToken = IERC20(_pairedToken);
        paired = PairedInterface(_pairedToken);
    }

    modifier onlyAdmin() {
        require(msg.sender == _admin || msg.sender == owner(), "Only Admin");
        _;
    }

    // MARK: - Only Owner
    function setAdmin(address admin) external onlyOwner {
        _admin = admin;
    }

    // MARK: - Only Admin
    function issueNewRound(bytes32 merkleRoot, uint256 additionalClaimable) external onlyAdmin {
        _whitelist = merkleRoot;
        paired.updateActiveSupply(additionalClaimable);
        emit NewRoundIssues(additionalClaimable);
    }

    // MARK: - Public
    function claim(uint256 amount, bytes32[] calldata proof) external nonReentrant {
        // check if caller has the right to claim
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, amount))));
        require(MerkleProof.verify(proof, _whitelist, leaf), "The address has no paired to claim.");

        // check if the tokens for that account are already claimed
        uint256 claimedToDate = _claimed[msg.sender];
        require(claimedToDate < amount, "These tokens have already been claimed.");

        // mark the tokens as claimed
        _claimed[msg.sender] = amount;

        // transfer paired tokens from this contract to the caller
        pairedToken.transfer(msg.sender, amount - claimedToDate);
    }
}