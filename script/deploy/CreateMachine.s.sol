// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IMachine} from "@makina-core/interfaces/IMachine.sol";

import {IHubStrategyDeploymentZap} from "src/interfaces/IHubStrategyDeploymentZap.sol";

import {CreateMachineZapBase} from "./base/CreateMachineZapBase.s.sol";

/// @dev Executes a previously scheduled `createMachine` deployment through the zap.
///      Must be run from the executor address used when scheduling, after the timelock delay has elapsed.
contract CreateMachine is CreateMachineZapBase {
    function _createCall() internal view override returns (Call memory) {
        IHubStrategyDeploymentZap.CreateMachineZapParams memory params = parseCreateMachineZapParams(inputJson);

        return Call({target: zap, data: abi.encodeCall(IHubStrategyDeploymentZap.createMachine, (params))});
    }

    function _afterCall(bytes memory returnData) internal override {
        deployedInstance = abi.decode(returnData, (address));

        if (bytes(outputPath).length == 0) {
            return;
        }

        string memory key = "key-create-machine-output-file";
        vm.serializeAddress(key, "machine", deployedInstance);
        vm.writeJson(vm.serializeAddress(key, "hubCaliber", IMachine(deployedInstance).hubCaliber()), outputPath);
    }

    function _recordDir() internal pure override returns (string memory) {
        return "create-machines";
    }
}
