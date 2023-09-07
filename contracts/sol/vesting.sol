// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Vesting is ReentrancyGuard {

    IERC20 public pairedToken;
    uint256 public startTimestamp;
    uint256 public constant DAY = 1 days;
    uint256 public constant CLIFF_PERIOD = 90 days;  // 90-day cliff

    struct Allocation {
        uint256 totalAmount; // Individualized vesting amounts
        uint256 claimedAmount;
        uint256 lastClaimedDay;
        uint256 vestingPeriodInDays; // Individualized vesting period
    }

    mapping(address => Allocation) public allocations;

    constructor(
        address pairedTokenAddress,
        uint256 _startTimestamp,
        address[] memory accounts,
        uint256[] memory amounts,
        uint256[] memory vestingPeriodsInDays 
    ) {
        pairedToken = IERC20(pairedTokenAddress);
        startTimestamp = _startTimestamp;

        require(
            accounts.length == amounts.length && amounts.length == vestingPeriodsInDays.length,
            "Mismatched array lengths"
        );

        for (uint256 i = 0; i < accounts.length; i++) {
            allocations[accounts[i]] = Allocation({
                totalAmount: amounts[i],
                claimedAmount: 0,
                lastClaimedDay: 0,
                vestingPeriodInDays: vestingPeriodsInDays[i]
            });
        }
    }

    function claimTokens() external nonReentrant {
        require(block.timestamp >= startTimestamp + CLIFF_PERIOD, "Cliff period has not passed yet");
        require(allocations[msg.sender].totalAmount > 0, "No allocation for this address");

        uint256 claimableAmount = calculateClaimableAmount(msg.sender);
        require(claimableAmount > 0, "No tokens available to claim");

        allocations[msg.sender].claimedAmount += claimableAmount;
        allocations[msg.sender].lastClaimedDay = (block.timestamp - startTimestamp) / DAY;
        pairedToken.transfer(msg.sender, claimableAmount);
    }

    function calculateClaimableAmount(address user) public view returns (uint256) {
        Allocation storage allocation = allocations[user];
        uint256 elapsedTime = block.timestamp - startTimestamp;

        if (elapsedTime < CLIFF_PERIOD) {
            return 0;
        }

        uint256 elapsedDays = elapsedTime / DAY;

        if (elapsedDays <= allocation.lastClaimedDay) {
            return 0;
        }

        uint256 newClaimableDays = elapsedDays - allocation.lastClaimedDay;

        uint256 claimableAmount = allocation.totalAmount * newClaimableDays / allocation.vestingPeriodInDays;

        uint256 remainingAmount = allocation.totalAmount - allocation.claimedAmount;

        if (claimableAmount > remainingAmount) {
            claimableAmount = remainingAmount;
        }

        if (elapsedDays >= allocation.vestingPeriodInDays && remainingAmount > 0) {
            claimableAmount = remainingAmount;
        }

        return claimableAmount;
    }
}
