// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

// solhint-disable no-console

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

import {IMakinaGovernable} from "@makina-core/interfaces/IMakinaGovernable.sol";
import {JsonParser} from "@makina-core-test/utils/JsonParser.sol";

import {IHubStrategyDeploymentZap} from "src/interfaces/IHubStrategyDeploymentZap.sol";

/// @notice Shared logic of the scripts scheduling and executing Machine deployments through the zap.
/// @dev The schedule and execute scripts of a given variant parse the same input file so the resulting payload
///      hashes are identical, which is required for the timelock check in the zap to pass.
///
/// Modes, selected by the `VIEW_MODE` env var:
///   - Broadcast (default): sends the call and, for the execute scripts, writes the deployed addresses to the
///     output file.
///   - View (`VIEW_MODE=true`): logs the zap address and the calldata, sends nothing and writes no file.
///
/// Env vars (read by the concrete scripts, unless `setParams` was called):
///   ZAP_OUTPUT_FILENAME       - zap deployment output file holding the zap address
///   HUB_STRAT_INPUT_FILENAME  - machine creation params input file
///   HUB_STRAT_OUTPUT_FILENAME - file to write the deployed addresses to (execute scripts, broadcast mode only)
///   VIEW_MODE (optional)      - true for view mode, unset or false for broadcast mode
abstract contract CreateMachineZapBase is Script, JsonParser {
    struct Call {
        address target;
        bytes data;
    }

    string public inputJson;
    string public outputPath;

    address public zap;

    bool public viewMode;

    /// @dev Overrides `makinaGovernableInitParams.initialAuthority` from the input file when non-zero.
    address public authority;

    address public deployedInstance;

    /// @dev Test hook to set the zap and the input/output filenames explicitly, instead of having `run` resolve them
    ///      from the env vars and the zap deployment output file. An empty output filename skips writing the output
    ///      file.
    function setParams(address _zap, string memory inputFilename, string memory outputFilename) public {
        zap = _zap;

        string memory basePath = string.concat(vm.projectRoot(), "/script/deployments/");

        inputJson = vm.readFile(string.concat(basePath, "inputs/", _recordDir(), "/", inputFilename));

        outputPath = bytes(outputFilename).length == 0
            ? ""
            : string.concat(basePath, "outputs/", _recordDir(), "/", outputFilename);
    }

    /// @dev Test hook to set the AccessManager governing the deployed strategy, which the input file of a test run
    ///      cannot hold, as it is deployed by the test itself.
    function setAuthority(address _authority) public {
        authority = _authority;
    }

    function setViewMode(bool _viewMode) public {
        viewMode = _viewMode;
    }

    /// @dev Reads `VIEW_MODE` and calls `setParams` with this script's env vars.
    function loadParamsFromEnv() public {
        viewMode = vm.envOr("VIEW_MODE", false);

        setParams(
            _zapFromRecord(vm.envString("ZAP_OUTPUT_FILENAME")),
            vm.envString("HUB_STRAT_INPUT_FILENAME"),
            viewMode ? "" : vm.envString("HUB_STRAT_OUTPUT_FILENAME")
        );
    }

    function run() public {
        if (bytes(inputJson).length == 0) {
            loadParamsFromEnv();
        }

        Call memory call = _createCall();

        if (viewMode) {
            _logCall(call);
            return;
        }

        vm.startBroadcast();

        bytes memory returnData = Address.functionCall(call.target, call.data);

        vm.stopBroadcast();

        _afterCall(returnData);
    }

    /// @dev The zap call to perform, built from the input file.
    function _createCall() internal view virtual returns (Call memory);

    /// @dev Directory name of this script's input and output records, under `inputs/` and `outputs/`.
    function _recordDir() internal pure virtual returns (string memory);

    /// @dev Handles the zap call return data, broadcast mode only. Nothing by default.
    function _afterCall(bytes memory returnData) internal virtual {}

    /// @dev Logs the target and calldata a script would broadcast in view mode.
    function _logCall(Call memory call) internal pure {
        console.log("target:", call.target);
        console.log("calldata:");
        console.logBytes(call.data);
    }

    /// @dev Zap address read from a zap deployment output record.
    function _zapFromRecord(string memory outputFilename) internal view returns (address) {
        string memory recordPath = string.concat(
            vm.projectRoot(), "/script/deployments/outputs/hub-strategy-deployment-zaps/", outputFilename
        );
        return vm.parseJsonAddress(vm.readFile(recordPath), ".HubStrategyDeploymentZap");
    }

    function parsePeripheryParams(string memory json, string memory key)
        internal
        pure
        returns (IHubStrategyDeploymentZap.PeripheryParams memory)
    {
        return IHubStrategyDeploymentZap.PeripheryParams({
            depositorImplemId: uint16(vm.parseJsonUint(json, string.concat(key, ".depositorImplemId"))),
            redeemerImplemId: uint16(vm.parseJsonUint(json, string.concat(key, ".redeemerImplemId"))),
            feeManagerImplemId: uint16(vm.parseJsonUint(json, string.concat(key, ".feeManagerImplemId"))),
            depositorInitData: vm.parseJsonBytes(json, string.concat(key, ".depositorInitData")),
            redeemerInitData: vm.parseJsonBytes(json, string.concat(key, ".redeemerInitData")),
            feeManagerInitData: vm.parseJsonBytes(json, string.concat(key, ".feeManagerInitData"))
        });
    }

    /// @dev Parses the governance params, applying the `authority` override when set.
    function parseGovernableParams(string memory json)
        internal
        view
        returns (IMakinaGovernable.MakinaGovernableInitParams memory mgParams)
    {
        mgParams = parseMakinaGovernableInitParams(json, ".makinaGovernableInitParams");

        if (authority != address(0)) {
            mgParams.initialAuthority = authority;
        }
    }

    function parseCreateMachineZapParams(string memory json)
        internal
        view
        returns (IHubStrategyDeploymentZap.CreateMachineZapParams memory)
    {
        return IHubStrategyDeploymentZap.CreateMachineZapParams({
            pParams: parsePeripheryParams(json, ".peripheryParams"),
            mParams: parseMachineInitParams(json, ".machineInitParams"),
            cParams: parseCaliberInitParams(json, ".caliberInitParams"),
            mgParams: parseGovernableParams(json),
            sscParams: parseSpokeSnapshotConsumerInitParams(json, ".spokeSnapshotConsumerInitParams"),
            baParams: parseBridgeAdaptersInitParams(json, ".bridgeAdapterInitParams"),
            accountingToken: vm.parseJsonAddress(json, ".accountingToken"),
            tokenName: vm.parseJsonString(json, ".shareTokenName"),
            tokenSymbol: vm.parseJsonString(json, ".shareTokenSymbol"),
            salt: vm.parseJsonBytes32(json, ".salt"),
            setupAMFunctionRoles: vm.parseJsonBool(json, ".setupAMFunctionRoles")
        });
    }
}
