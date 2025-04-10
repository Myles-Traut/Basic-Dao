// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";

import {Box} from "../src/Box.sol";
import {GovToken} from "../src/GovToken.sol";
import {DaoGovernor} from "../src/DaoGovernor.sol";
import {DaoTimelockController} from "../src/DaoTimelockController.sol";

contract DaoVotingTest is Test {
    GovToken public govToken;
    DaoGovernor public governor;
    DaoTimelockController public timelock;
    Box public box;

    address public user = makeAddr("user");

    uint256 public constant MIN_DELAY = 3600; // 1 hour
    uint256 public constant VOTING_DELAY = 7200; // 2 hours
    uint256 public constant VOTING_PERIOD = 50400; // 1 week

    bytes[] calldatas;
    address[] targets;
    address[] proposers;
    address[] executors;
    uint256[] values;

    function setUp() public {
        vm.startPrank(user);
        govToken = new GovToken();
        assertEq(govToken.balanceOf(user), 1_000_000 ether);
        govToken.delegate(user); // Delegate voting power to self
        timelock = new DaoTimelockController(MIN_DELAY, proposers, executors, user);
        governor = new DaoGovernor(govToken, timelock);
        box = new Box(address(timelock));

        bytes32 PROPOSER_ROLE = timelock.PROPOSER_ROLE();
        bytes32 EXECUTOR_ROLE = timelock.EXECUTOR_ROLE();
        bytes32 ADMIN_ROLE = timelock.DEFAULT_ADMIN_ROLE();

        timelock.grantRole(PROPOSER_ROLE, address(governor));
        timelock.grantRole(EXECUTOR_ROLE, address(0));
        timelock.revokeRole(ADMIN_ROLE, user);

        vm.stopPrank();
    }

    function testCannotUpdateBoxWithoutGovernance() public {
        vm.expectRevert();
        box.setNumber(1);
    }

    function testGovernanceUpdatesBox() public {
        uint256 valueToStore = 888;

        string memory description = "Update box value";
        bytes memory callData = abi.encodeWithSignature("setNumber(uint256)", valueToStore);
        calldatas.push(callData);
        values.push(0);
        targets.push(address(box));

        // 1. Propose to the DAO
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        // View state
        console.log("Proposal State: ", uint256(governor.state(proposalId)));

        vm.warp(block.timestamp + VOTING_DELAY + 1);
        vm.roll(block.number + VOTING_DELAY + 1);

        console.log("Proposal State: ", uint256(governor.state(proposalId)));

        // 2. Vote
        string memory reason = "I like to vote yes";
        uint8 voteWay = 1; // 1 = for, 0 = against, 2 = abstain

        vm.prank(user);
        governor.castVoteWithReason(proposalId, voteWay, reason);

        vm.warp(block.timestamp + VOTING_PERIOD + 1000);
        vm.roll(block.number + VOTING_PERIOD + 1000);

        // 3. Queue the tx
        bytes32 descriptionHash = keccak256(abi.encodePacked(description));
        governor.queue(targets, values, calldatas, descriptionHash);

        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);

        assertEq(box.getNumber(), 0);

        // 4. Execute the tx
        governor.execute(targets, values, calldatas, descriptionHash);

        assertEq(box.getNumber(), valueToStore);
    }
}
