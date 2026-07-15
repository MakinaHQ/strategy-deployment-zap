// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IMachine} from "@makina-core/interfaces/IMachine.sol";

import {IHubStrategyDeploymentZap} from "src/interfaces/IHubStrategyDeploymentZap.sol";

import {CreateMachineZapBase} from "./CreateMachineZapBase.s.sol";

/// @dev Executes a previously scheduled `createMachineFromPreDeposit` deployment through the zap.
///      Must be run from the executor address used when scheduling, after the timelock delay has elapsed.
contract CreateMachineFromPreDeposit is CreateMachineZapBase {
    string public zapOutputJson;
    string public inputJson;
    string public outputPath;

    address public deployedInstance;

    constructor() {
        string memory zapOutputFilename = vm.envString("ZAP_OUTPUT_FILENAME");
        string memory inputFilename = vm.envString("HUB_STRAT_INPUT_FILENAME");
        string memory outputFilename = vm.envString("HUB_STRAT_OUTPUT_FILENAME");

        string memory basePath = string.concat(vm.projectRoot(), "/script/deployments/");

        // load zap deployment output
        string memory zapOutputPath = string.concat(basePath, "outputs/hub-strategy-deployment-zaps/");
        zapOutputPath = string.concat(zapOutputPath, zapOutputFilename);
        zapOutputJson = vm.readFile(zapOutputPath);

        // load input params
        string memory inputPath = string.concat(basePath, "inputs/create-machines-from-pre-deposit/");
        inputPath = string.concat(inputPath, inputFilename);
        inputJson = vm.readFile(inputPath);

        // output path to later save deployed instance
        outputPath = string.concat(basePath, "outputs/create-machines-from-pre-deposit/");
        outputPath = string.concat(outputPath, outputFilename);
    }

    function run() public {
        IHubStrategyDeploymentZap zap =
            IHubStrategyDeploymentZap(vm.parseJsonAddress(zapOutputJson, ".HubStrategyDeploymentZap"));

        IHubStrategyDeploymentZap.CreateMachineFromPreDepositZapParams memory params =
            parseCreateMachineFromPreDepositZapParams(inputJson);

        if (viewOnly) {
            bytes memory data = abi.encodeCall(IHubStrategyDeploymentZap.createMachineFromPreDeposit, (params));
            _logCalldata(address(zap), data);
            return;
        }

        vm.startBroadcast();
        deployedInstance = zap.createMachineFromPreDeposit(params);
        vm.stopBroadcast();

        // write to file
        string memory key = "key-create-machine-from-pre-deposit-output-file";
        vm.serializeAddress(key, "machine", deployedInstance);
        vm.writeJson(vm.serializeAddress(key, "hubCaliber", IMachine(deployedInstance).hubCaliber()), outputPath);
    }
}
