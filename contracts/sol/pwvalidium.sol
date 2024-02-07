// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";


contract PWValidium is Ownable {

    address public _logicProxy;
    address public _admin;

    mapping (uint8 => bytes32) public _validityProofs;
    mapping (uint8 => string) public _proofTypes;

    event ProofUpdated(uint8 idx, bytes32 root);
    event GetTime(uint256 time);

    constructor() {}

    modifier onlyAdmin() {
        require(msg.sender == _admin || msg.sender == owner(), "Only Admin");
        _;
    }
    
    modifier onlyProxy() {
        require(msg.sender == _logicProxy || msg.sender == _admin || msg.sender == owner(), "Only Proxy");
        _;
    }

    // MARK: - Only Owner
    function setAdmin(address admin) external onlyOwner {
        _admin = admin;
    }

    // MARK: - Only Admin
    function setLogicProxy(address logicProxy) external onlyAdmin() {
        _logicProxy = logicProxy;
    }

    function setProofType(uint8 idx, string memory proofType) external onlyAdmin() {
        _proofTypes[idx] = proofType;
    }

    // MARK: - Only Logic Proxy
    function addProof(uint8 idx, bytes32 root) external onlyProxy() {
        require(!_isStringEmpty(_proofTypes[idx]), "setting invalid proof type");
        _validityProofs[idx] = root;

        emit ProofUpdated(idx, root);
    }

    // Mark: - View
    function getMerkleRoot(uint8 idx) external view returns (bytes32) {
        require(!_isStringEmpty(_proofTypes[idx]), "requesting invalid proof type");
        return _validityProofs[idx];
    }

    function getTime() external returns (uint256) {
        uint256 time = block.timestamp;
        emit GetTime(time);
        return time;
    }

    // Mark: - Internal
    function _isStringEmpty(string memory data) internal pure returns (bool) {
        return bytes(data).length == 0;
    }

}