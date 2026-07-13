// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {Base} from "../../test/base/Base.sol";

contract DeployHubStrategyDeploymentZap is Base, Script {
    using stdJson for string;

    string public inputJson;
    string public outputPath;

    address public deployedInstance;

    constructor() {
        string memory inputFilename = vm.envString("ZAP_INPUT_FILENAME");
        string memory outputFilename = vm.envString("ZAP_OUTPUT_FILENAME");

        string memory basePath = string.concat(vm.projectRoot(), "/script/deployments/");

        // load input params
        string memory inputPath = string.concat(basePath, "inputs/hub-strategy-deployment-zaps/");
        inputPath = string.concat(inputPath, inputFilename);
        inputJson = vm.readFile(inputPath);

        // output path to later save deployed contract
        outputPath = string.concat(basePath, "outputs/hub-strategy-deployment-zaps/");
        outputPath = string.concat(outputPath, outputFilename);
    }

    function run() public {
        address initialOwner = vm.parseJsonAddress(inputJson, ".initialOwner");
        address hubCoreFactory = vm.parseJsonAddress(inputJson, ".hubCoreFactory");
        address hubPeripheryFactory = vm.parseJsonAddress(inputJson, ".hubPeripheryFactory");

        // start broadcasting transactions
        vm.startBroadcast();

        deployedInstance = address(deployHubStrategyDeploymentZap(initialOwner, hubCoreFactory, hubPeripheryFactory));

        vm.stopBroadcast();

        // write to file
        string memory key = "key-deploy-hub-strategy-deployment-zap-output-file";
        vm.writeJson(vm.serializeAddress(key, "HubStrategyDeploymentZap", deployedInstance), outputPath);
    }
}
