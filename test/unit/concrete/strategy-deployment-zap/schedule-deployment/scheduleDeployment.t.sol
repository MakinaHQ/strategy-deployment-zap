// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IStrategyDeploymentZap} from "src/interfaces/IStrategyDeploymentZap.sol";

import {StrategyDeploymentZap_Unit_Concrete_Test} from "../StrategyDeploymentZap.t.sol";

abstract contract ScheduleDeployment_Unit_Concrete_Test is StrategyDeploymentZap_Unit_Concrete_Test {
    address internal executor;
    bytes internal payload;

    function setUp() public virtual override {
        executor = makeAddr("Executor");
        payload = hex"1234";
    }

    function test_RevertWhen_CallerNotOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        strategyDeploymentZap.scheduleDeployment(address(0), "", 0);
    }

    function test_RevertWhen_DeploymentAlreadyExecuted() public {
        bytes32 payloadHash = keccak256(payload);

        // Simulate execution of a deployment
        vm.store(
            address(strategyDeploymentZap),
            keccak256(abi.encode(payloadHash, keccak256(abi.encode(executor, 1)))),
            bytes32(type(uint256).max) // EXECUTED_TIMEPOINT
        );

        vm.expectRevert(IStrategyDeploymentZap.DeploymentAlreadyExecuted.selector);
        vm.prank(dao);
        strategyDeploymentZap.scheduleDeployment(address(executor), payload, 0);
    }

    function test_RevertWhen_DeploymentAlreadyScheduled() public {
        vm.prank(dao);
        strategyDeploymentZap.scheduleDeployment(address(executor), payload, 0);

        vm.expectRevert(IStrategyDeploymentZap.DeploymentAlreadyScheduled.selector);
        vm.prank(dao);
        strategyDeploymentZap.scheduleDeployment(address(executor), payload, 0);
    }

    function test_RevertWhen_InvalidDelay() public {
        vm.expectRevert(IStrategyDeploymentZap.InvalidDelay.selector);
        vm.prank(dao);
        strategyDeploymentZap.scheduleDeployment(address(executor), payload, type(uint256).max - block.timestamp);
    }

    function test_ScheduleDeployment() public {
        vm.prank(dao);
        vm.expectEmit(true, true, false, true);
        emit IStrategyDeploymentZap.DeploymentScheduled(address(executor), keccak256(payload), block.timestamp);
        strategyDeploymentZap.scheduleDeployment(address(executor), payload, 0);
    }
}
