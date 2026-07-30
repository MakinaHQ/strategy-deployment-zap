// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

// solhint-disable no-console

import {Script} from "forge-std/Script.sol";
import {console2} from "forge-std/console2.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {JsonParser} from "@makina-core-test/utils/JsonParser.sol";

import {IHubStrategyDeploymentZap} from "src/interfaces/IHubStrategyDeploymentZap.sol";

/// @dev Shared input-parsing logic for the scripts scheduling and executing Machine deployments through the zap.
///      The schedule and execute scripts of a given variant parse the same input file so the resulting payload
///      hashes are identical, which is required for the timelock check in the zap to pass.
abstract contract CreateMachineZapBase is Script, JsonParser {
    using stdJson for string;

    /// @dev When true, scripts log the calldata they would broadcast instead of sending any transaction.
    bool public viewOnly = vm.envOr("VIEW_ONLY", false);

    /// @dev Logs the target and calldata a script would broadcast in view mode.
    function _logCalldata(address target, bytes memory data) internal pure {
        console2.log("target:", target);
        console2.log("calldata:");
        console2.logBytes(data);
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

    function parseCreateMachineZapParams(string memory json)
        internal
        view
        returns (IHubStrategyDeploymentZap.CreateMachineZapParams memory)
    {
        return IHubStrategyDeploymentZap.CreateMachineZapParams({
            pParams: parsePeripheryParams(json, ".peripheryParams"),
            mParams: parseMachineInitParams(json, ".machineInitParams"),
            cParams: parseCaliberInitParams(json, ".caliberInitParams"),
            mgParams: parseMakinaGovernableInitParams(json, ".makinaGovernableInitParams"),
            sscParams: parseSpokeSnapshotConsumerInitParams(json, ".spokeSnapshotConsumerInitParams"),
            baParams: parseBridgeAdaptersInitParams(json, ".bridgeAdapterInitParams"),
            accountingToken: vm.parseJsonAddress(json, ".accountingToken"),
            tokenName: vm.parseJsonString(json, ".shareTokenName"),
            tokenSymbol: vm.parseJsonString(json, ".shareTokenSymbol"),
            salt: vm.parseJsonBytes32(json, ".salt"),
            setupAMFunctionRoles: vm.parseJsonBool(json, ".setupAMFunctionRoles")
        });
    }

    function parseCreateMachineFromPreDepositZapParams(string memory json)
        internal
        view
        returns (IHubStrategyDeploymentZap.CreateMachineFromPreDepositZapParams memory)
    {
        return IHubStrategyDeploymentZap.CreateMachineFromPreDepositZapParams({
            pParams: parsePeripheryParams(json, ".peripheryParams"),
            mParams: parseMachineInitParams(json, ".machineInitParams"),
            cParams: parseCaliberInitParams(json, ".caliberInitParams"),
            mgParams: parseMakinaGovernableInitParams(json, ".makinaGovernableInitParams"),
            sscParams: parseSpokeSnapshotConsumerInitParams(json, ".spokeSnapshotConsumerInitParams"),
            baParams: parseBridgeAdaptersInitParams(json, ".bridgeAdapterInitParams"),
            preDepositVault: vm.parseJsonAddress(json, ".preDepositVault"),
            salt: vm.parseJsonBytes32(json, ".salt"),
            setupAMFunctionRoles: vm.parseJsonBool(json, ".setupAMFunctionRoles")
        });
    }
}
