// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

interface SoulBoundTokenInterface {
    
    function ownerTickets(
        address account, 
        bytes32[] memory proof, 
        uint256 amount, 
        uint8 level
        ) external returns (uint256);

    function _ownedToken(address account) external returns (uint256);
    
}

contract TicketToken is ERC1155, Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;

    SoulBoundTokenInterface _sbt;

    string public constant name = "Ticket Token";
    string public constant symbol = "TKT";

    uint256 public totalSupply;
    uint256 public _currentRound;
    mapping (uint256 => string) public _tokenURIs;
    mapping (bytes32 => bool) public _claimed;
    mapping (address => bool) public _migrationRefund;

    bytes32 public _migrationMerkleRoot;

    address public _admin;

    event NewRoundIssued(uint256 round);
    event RefundIssued(address claimer);

    constructor() ERC1155("some//uri//tbc") {}

    modifier onlyAdmin() {
        require(msg.sender == _admin || msg.sender == owner(), "Only Admin");
        _;
    }

    modifier onlyPermitted(address to) {
        require(msg.sender == _admin || msg.sender == owner() || msg.sender == to, "Not permitted to call on behalf of this address.");
        _;
    }

    // MARK: - Only Owner
    function setAdmin(address admin) external onlyOwner {
        _admin = admin;
    }

    function setTokenUri(string memory uri) external onlyOwner {
        _setURI(uri);
    }

    function setSoulBoundToken(address sbt) external onlyOwner {
        _sbt = SoulBoundTokenInterface(sbt);
    }

    // MARK: - Only Admin
    function issueNewRound() external onlyAdmin {
        _currentRound++;
        emit NewRoundIssued(_currentRound);
    }

    function issueSingleRefund(address to) external onlyAdmin {
        require(_sbt._ownedToken(to) != 0, "trying to refund user with no SOUL");
        _mint(to, 0, 1, "");
        totalSupply += 1;
        emit RefundIssued(to);
    }

    function setMigrationMerkleRoot(bytes32 merkleRoot) external onlyAdmin {
        _migrationMerkleRoot = merkleRoot;
    }

    function handleMigration(address to, uint256 amount, bytes32[] memory proof) external onlyAdmin {
        require(!_migrationRefund[to], "Already refunded");

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(to, amount))));
        require(MerkleProof.verify(proof, _migrationMerkleRoot, leaf), "Not listed to partake migration");

        _migrationRefund[to] = true;

        _mint(to, 0, amount, "");
        totalSupply += amount;
    }

    // MARK: - Public 
    function claimTicket(
        bytes32[] memory proof, 
        uint256 amount, 
        uint8 level,
        address to
    ) external nonReentrant onlyPermitted(to) {
        // check if the tickets for that account is already claimed
        bytes32 key = getKeyForId(to);
        require(!_isClaimed(key), "This ticket has already been claimed.");

        uint256 toClaim = _sbt.ownerTickets(to, proof, amount, level);

        // check if to address is owner of some souls with ticket rights from extrnal soulbound contract
        require(toClaim > 0, "The address has no tickets to claim.");

        _setClaimed(key);
        // transfer the ticket from this contract to the msg.sender
        _mint(to, 0, toClaim, "");

        totalSupply += toClaim;
    }

    function burn(uint256 tokenId, address _forOwner) external onlyPermitted(_forOwner) {
        require(balanceOf(_forOwner, 0) > 0, "No tickets owned to burn");
        _burn(_forOwner, tokenId, 1);
        totalSupply -= 1;
    }

    // MARK: - "Resettable" Mapping
    function getKeyForId(address user) internal view returns(bytes32) {
        return keccak256(abi.encodePacked(_currentRound, user));
    }

    function _isClaimed(bytes32 key) internal view returns(bool) {
        return _claimed[key];
    }

    function _setClaimed(bytes32 key) internal {
        _claimed[key] = true;
    }
}