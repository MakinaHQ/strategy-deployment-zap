// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IHubStrategyDeploymentZap} from "src/interfaces/IHubStrategyDeploymentZap.sol";
import {IStrategyDeploymentZap} from "src/interfaces/IStrategyDeploymentZap.sol";

import {CreateMachineZapBase} from "./base/CreateMachineZapBase.s.sol";

/// @dev Schedules a `createMachine` deployment through the zap. Must be run from the zap owner.
contract ScheduleCreateMachine is CreateMachineZapBase {
    function _createCall() internal view override returns (Call memory) {
        IHubStrategyDeploymentZap.CreateMachineZapParams memory params = parseCreateMachineZapParams(inputJson);

        address executor = vm.parseJsonAddress(inputJson, ".executor");
        uint256 delay = vm.parseJsonUint(inputJson, ".delay");

        bytes memory payload = abi.encodeCall(IHubStrategyDeploymentZap.createMachine, (params));

        return Call({
            target: zap, data: abi.encodeCall(IStrategyDeploymentZap.scheduleDeployment, (executor, payload, delay))
        });
    }

    function _recordDir() internal pure override returns (string memory) {
        return "create-machines";
    }
}
