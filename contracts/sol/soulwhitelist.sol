// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract SoulWhitelist is Ownable {

    bytes32 public _whitelist;
    address public _admin;

    event WhitelistUpdated(bytes32 merkle_root);

    constructor() {}

    modifier onlyAdmin() {
        require(msg.sender == _admin || msg.sender == owner(), "Only Admin");
        _;
    }

    // MARK: - Only Owner
    function setAdmin(address admin) external onlyOwner {
        _admin = admin;
    }

    
    // MARK: - Only Admin
    function updateWhitelist(bytes32 merkle_root) external onlyAdmin {
        _whitelist = merkle_root;
        emit WhitelistUpdated(merkle_root);
    }

    // MARK: - Public
    function whitelisted(
        bytes32[] memory proof, 
        address account, 
        uint256 amount, 
        uint256 level
        ) public view returns (uint256) {
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account, amount, level))));
        uint256 val = MerkleProof.verify(proof, _whitelist, leaf) ? amount : 0;

        return val;
    }


}