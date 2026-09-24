// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

// solhint-disable gas-custom-errors, reason-string

import {Script} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {CreateXUtils} from "@makina-core-script/deploy/utils/CreateXUtils.sol";

import {Base} from "../../test/base/Base.sol";

contract DeployHubStrategyDeploymentZap is Base, Script, CreateXUtils {
    using stdJson for string;

    string public inputJson;
    string public outputPath;

    address public deployer;

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

        (, deployer,) = vm.readCallers();

        deployedInstance = address(deployHubStrategyDeploymentZap(initialOwner, hubCoreFactory, hubPeripheryFactory));

        vm.stopBroadcast();

        // write to file
        string memory key = "key-deploy-hub-strategy-deployment-zap-output-file";
        vm.writeJson(vm.serializeAddress(key, "HubStrategyDeploymentZap", deployedInstance), outputPath);
    }

    /// @dev Deploys through CreateX at the deployer-bound address and asserts it. The zap is deployed under a
    ///      versioned, non-zero salt domain, so this is always a CREATE3 slot: an occupied one reverts before
    ///      broadcasting, with a readable error instead of CreateX's opaque one.
    function _deployCode(bytes memory bytecode, bytes32 salt) internal override returns (address deployed) {
        deployed = _computeCreateXAddress(bytecode, salt, deployer);

        if (deployed.code.length != 0) {
            revert(
                string.concat(
                    "DeployHubStrategyDeploymentZap: CREATE3 target already has code: ", vm.toString(deployed)
                )
            );
        }

        require(
            _deployCodeCreateX(bytecode, salt, deployer) == deployed,
            "DeployHubStrategyDeploymentZap: CreateX address mismatch"
        );
    }
}
