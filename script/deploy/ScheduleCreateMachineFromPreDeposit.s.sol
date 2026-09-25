// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IHubStrategyDeploymentZap} from "src/interfaces/IHubStrategyDeploymentZap.sol";
import {IStrategyDeploymentZap} from "src/interfaces/IStrategyDeploymentZap.sol";

import {CreateMachineFromPreDepositZapBase} from "./base/CreateMachineFromPreDepositZapBase.s.sol";

/// @dev Schedules a `createMachineFromPreDeposit` deployment through the zap. Must be run from the zap owner.
contract ScheduleCreateMachineFromPreDeposit is CreateMachineFromPreDepositZapBase {
    function _createCall() internal view override returns (Call memory) {
        IHubStrategyDeploymentZap.CreateMachineFromPreDepositZapParams memory params =
            parseCreateMachineFromPreDepositZapParams(inputJson);

        address executor = vm.parseJsonAddress(inputJson, ".executor");
        uint256 delay = vm.parseJsonUint(inputJson, ".delay");

        bytes memory payload = abi.encodeCall(IHubStrategyDeploymentZap.createMachineFromPreDeposit, (params));

        return Call({
            target: zap, data: abi.encodeCall(IStrategyDeploymentZap.scheduleDeployment, (executor, payload, delay))
        });
    }
}
