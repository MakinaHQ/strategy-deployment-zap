// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IHubStrategyDeploymentZap} from "src/interfaces/IHubStrategyDeploymentZap.sol";

import {CreateMachineZapBase} from "./CreateMachineZapBase.s.sol";

/// @notice Shared logic of the scripts scheduling and executing Machine deployments from a Pre-Deposit Vault.
abstract contract CreateMachineFromPreDepositZapBase is CreateMachineZapBase {
    /// @dev Overrides `preDepositVault` from the input file when non-zero.
    address public preDepositVault;

    /// @dev Test hook to set the Pre-Deposit Vault to migrate, which the input file of a test run cannot hold, as it
    ///      is deployed by the test itself.
    function setPreDepositVault(address _preDepositVault) public {
        preDepositVault = _preDepositVault;
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
            mgParams: parseGovernableParams(json),
            sscParams: parseSpokeSnapshotConsumerInitParams(json, ".spokeSnapshotConsumerInitParams"),
            baParams: parseBridgeAdaptersInitParams(json, ".bridgeAdapterInitParams"),
            preDepositVault: preDepositVault != address(0)
                ? preDepositVault
                : vm.parseJsonAddress(json, ".preDepositVault"),
            salt: vm.parseJsonBytes32(json, ".salt"),
            setupAMFunctionRoles: vm.parseJsonBool(json, ".setupAMFunctionRoles")
        });
    }

    function _recordDir() internal pure override returns (string memory) {
        return "create-machines-from-pre-deposit";
    }
}
