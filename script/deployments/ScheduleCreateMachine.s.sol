// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IHubStrategyDeploymentZap} from "src/interfaces/IHubStrategyDeploymentZap.sol";
import {IStrategyDeploymentZap} from "src/interfaces/IStrategyDeploymentZap.sol";

import {CreateMachineZapBase} from "./CreateMachineZapBase.s.sol";

/// @dev Schedules a `createMachine` deployment through the zap. Must be run from the zap owner.
contract ScheduleCreateMachine is CreateMachineZapBase {
    string public zapOutputJson;
    string public inputJson;

    constructor() {
        string memory zapOutputFilename = vm.envString("ZAP_OUTPUT_FILENAME");
        string memory inputFilename = vm.envString("HUB_STRAT_INPUT_FILENAME");

        string memory basePath = string.concat(vm.projectRoot(), "/script/deployments/");

        // load zap deployment output
        string memory zapOutputPath = string.concat(basePath, "outputs/hub-strategy-deployment-zaps/");
        zapOutputPath = string.concat(zapOutputPath, zapOutputFilename);
        zapOutputJson = vm.readFile(zapOutputPath);

        // load input params
        string memory inputPath = string.concat(basePath, "inputs/create-machines/");
        inputPath = string.concat(inputPath, inputFilename);
        inputJson = vm.readFile(inputPath);
    }

    function run() public {
        IStrategyDeploymentZap zap =
            IStrategyDeploymentZap(vm.parseJsonAddress(zapOutputJson, ".HubStrategyDeploymentZap"));

        IHubStrategyDeploymentZap.CreateMachineZapParams memory params = parseCreateMachineZapParams(inputJson);

        address executor = vm.parseJsonAddress(inputJson, ".executor");
        uint256 delay = vm.parseJsonUint(inputJson, ".delay");

        bytes memory payload = abi.encodeCall(IHubStrategyDeploymentZap.createMachine, (params));

        vm.startBroadcast();
        zap.scheduleDeployment(executor, payload, delay);
        vm.stopBroadcast();
    }
}
