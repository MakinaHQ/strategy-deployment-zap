// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IMachine} from "@makina-core/interfaces/IMachine.sol";

import {IHubStrategyDeploymentZap} from "src/interfaces/IHubStrategyDeploymentZap.sol";

import {CreateMachineFromPreDepositZapBase} from "./CreateMachineFromPreDepositZapBase.s.sol";

/// @dev Executes a previously scheduled `createMachineFromPreDeposit` deployment through the zap.
///      Must be run from the executor address used when scheduling, after the timelock delay has elapsed.
contract CreateMachineFromPreDeposit is CreateMachineFromPreDepositZapBase {
    function _createCall() internal view override returns (Call memory) {
        IHubStrategyDeploymentZap.CreateMachineFromPreDepositZapParams memory params =
            parseCreateMachineFromPreDepositZapParams(inputJson);

        return
            Call({target: zap, data: abi.encodeCall(IHubStrategyDeploymentZap.createMachineFromPreDeposit, (params))});
    }

    function _afterCall(bytes memory returnData) internal override {
        deployedInstance = abi.decode(returnData, (address));

        if (bytes(outputPath).length == 0) {
            return;
        }

        string memory key = "key-create-machine-from-pre-deposit-output-file";
        vm.serializeAddress(key, "machine", deployedInstance);
        vm.writeJson(vm.serializeAddress(key, "hubCaliber", IMachine(deployedInstance).hubCaliber()), outputPath);
    }
}
