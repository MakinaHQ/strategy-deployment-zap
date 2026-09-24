// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

// solhint-disable gas-custom-errors, reason-string

import {Script} from "forge-std/Script.sol";

import {CreateXUtils} from "@makina-core-script/deploy/utils/CreateXUtils.sol";

import {Base} from "../../test/base/Base.sol";

/// @dev Deploys the HubStrategyDeploymentZap.
///
/// Env vars (unless `setFilenames` was called):
///   ZAP_INPUT_FILENAME  - zap init params input file
///   ZAP_OUTPUT_FILENAME - file to write the deployed address to
contract DeployHubStrategyDeploymentZap is Base, Script, CreateXUtils {
    string public inputJson;
    string public outputPath;

    address public deployer;

    address public deployedInstance;

    /// @dev Overrides the factory addresses from the input file when non-zero.
    address public hubCoreFactory;
    address public hubPeripheryFactory;

    /// @dev Test hook to set the input/output filenames explicitly, instead of having `run` resolve them from the
    ///      env vars. An empty output filename skips writing the output file.
    function setFilenames(string memory inputFilename, string memory outputFilename) public {
        string memory basePath = string.concat(vm.projectRoot(), "/script/deployments/");

        inputJson = vm.readFile(string.concat(basePath, "inputs/hub-strategy-deployment-zaps/", inputFilename));

        outputPath = bytes(outputFilename).length == 0
            ? ""
            : string.concat(basePath, "outputs/hub-strategy-deployment-zaps/", outputFilename);
    }

    /// @dev Test hook to set the core and periphery factories, which the input file of a test run cannot hold, as
    ///      they are deployed by the test itself.
    function setFactories(address _hubCoreFactory, address _hubPeripheryFactory) public {
        hubCoreFactory = _hubCoreFactory;
        hubPeripheryFactory = _hubPeripheryFactory;
    }

    /// @dev Calls `setParams` with this script's env vars.
    function loadParamsFromEnv() public {
        setFilenames(vm.envString("ZAP_INPUT_FILENAME"), vm.envString("ZAP_OUTPUT_FILENAME"));
    }

    function run() public {
        if (bytes(inputJson).length == 0) {
            loadParamsFromEnv();
        }

        address initialOwner = vm.parseJsonAddress(inputJson, ".initialOwner");

        address coreFactory =
            hubCoreFactory != address(0) ? hubCoreFactory : vm.parseJsonAddress(inputJson, ".hubCoreFactory");
        address peripheryFactory = hubPeripheryFactory != address(0)
            ? hubPeripheryFactory
            : vm.parseJsonAddress(inputJson, ".hubPeripheryFactory");

        // start broadcasting transactions
        vm.startBroadcast();

        (, deployer,) = vm.readCallers();

        deployedInstance = address(deployHubStrategyDeploymentZap(initialOwner, coreFactory, peripheryFactory));

        vm.stopBroadcast();

        if (bytes(outputPath).length == 0) {
            return;
        }

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
