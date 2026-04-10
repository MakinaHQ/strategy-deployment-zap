// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IBridgeAdapterFactory} from "@makina-core/interfaces/IBridgeAdapterFactory.sol";
import {ICaliber} from "@makina-core/interfaces/ICaliber.sol";
import {IMachine} from "@makina-core/interfaces/IMachine.sol";
import {IMakinaGovernable} from "@makina-core/interfaces/IMakinaGovernable.sol";

import {IStrategyDeploymentZap} from "./IStrategyDeploymentZap.sol";

interface IHubStrategyDeploymentZap is IStrategyDeploymentZap {
    error ConflictingPeripheryParams();

    struct PeripheryParams {
        uint16 depositorImplemId;
        uint16 redeemerImplemId;
        uint16 feeManagerImplemId;
        bytes depositorInitData;
        bytes redeemerInitData;
        bytes feeManagerInitData;
    }

    struct CreateMachineZapParams {
        PeripheryParams pParams;
        IMachine.MachineInitParams mParams;
        ICaliber.CaliberInitParams cParams;
        IMakinaGovernable.MakinaGovernableInitParams mgParams;
        IBridgeAdapterFactory.BridgeAdapterInitParams[] baParams;
        address accountingToken;
        string tokenName;
        string tokenSymbol;
        bytes32 salt;
        bool setupAMFunctionRoles;
    }

    struct CreateMachineFromPreDepositZapParams {
        PeripheryParams pParams;
        IMachine.MachineInitParams mParams;
        ICaliber.CaliberInitParams cParams;
        IMakinaGovernable.MakinaGovernableInitParams mgParams;
        IBridgeAdapterFactory.BridgeAdapterInitParams[] baParams;
        address preDepositVault;
        bytes32 salt;
        bool setupAMFunctionRoles;
    }

    /// @notice Address of the HubCoreFactory used for deployments.
    function hubCoreFactory() external view returns (address);

    /// @notice Address of the HubPeripheryFactory used for deployments.
    function hubPeripheryFactory() external view returns (address);

    /// @notice Deploys and configures a new Machine instance.
    /// @param mzParams Initialization parameters for the Machine and its associated periphery modules.
    /// @return The address of the deployed machine.
    function createMachine(CreateMachineZapParams calldata mzParams) external returns (address);

    /// @notice Deploys a new Machine instance, migrates an existing PreDepositVault instance to it and configures it.
    /// @param mzParams Initialization parameters for the Machine and its associated periphery modules.
    /// @return The address of the deployed machine.
    function createMachineFromPreDeposit(CreateMachineFromPreDepositZapParams calldata mzParams)
        external
        returns (address);
}
