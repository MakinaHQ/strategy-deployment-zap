// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IStrategyDeploymentZap} from "src/interfaces/IStrategyDeploymentZap.sol";

import {StrategyDeploymentZap_Unit_Concrete_Test} from "../StrategyDeploymentZap.t.sol";

abstract contract CancelDeployment_Unit_Concrete_Test is StrategyDeploymentZap_Unit_Concrete_Test {
    address internal executor;
    bytes internal payload;
    bytes32 internal payloadHash;

    function setUp() public virtual override {
        executor = makeAddr("Executor");
        payload = hex"1234";
        payloadHash = keccak256(payload);
    }

    function test_RevertWhen_CallerNotOwner() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, address(this)));
        strategyDeploymentZap.cancelDeployment(address(0), 0);
    }

    function test_RevertWhen_DeploymentNotScheduled() public {
        vm.expectRevert(IStrategyDeploymentZap.DeploymentNotScheduled.selector);
        vm.prank(dao);
        strategyDeploymentZap.cancelDeployment(address(0), 0);
    }

    function test_RevertWhen_DeploymentAlreadyExecuted() public {
        // Simulate execution of a deployment
        vm.store(
            address(strategyDeploymentZap),
            keccak256(abi.encode(payloadHash, keccak256(abi.encode(executor, 1)))),
            bytes32(type(uint256).max) // EXECUTED_TIMEPOINT
        );

        vm.expectRevert(IStrategyDeploymentZap.DeploymentAlreadyExecuted.selector);
        vm.prank(dao);
        strategyDeploymentZap.cancelDeployment(address(executor), payloadHash);
    }

    function test_CancelDeployment_BeforeTimepoint() public {
        vm.startPrank(dao);

        strategyDeploymentZap.scheduleDeployment(address(executor), payload, 1 hours);

        vm.expectEmit(true, true, false, true);
        emit IStrategyDeploymentZap.DeploymentCanceled(address(executor), payloadHash);
        strategyDeploymentZap.cancelDeployment(address(executor), payloadHash);
    }

    function test_CancelDeployment_AfterTimepoint() public {
        vm.startPrank(dao);

        strategyDeploymentZap.scheduleDeployment(address(executor), payload, 1 hours);

        skip(1 hours + 1);

        vm.expectEmit(true, true, false, true);
        emit IStrategyDeploymentZap.DeploymentCanceled(address(executor), payloadHash);
        strategyDeploymentZap.cancelDeployment(address(executor), payloadHash);
    }
}
