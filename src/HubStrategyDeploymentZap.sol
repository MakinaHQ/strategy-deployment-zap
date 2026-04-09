// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IHubCoreFactory} from "@makina-core/interfaces/IHubCoreFactory.sol";
import {IMachine} from "@makina-core/interfaces/IMachine.sol";

import {IHubPeripheryFactory} from "@makina-periphery/interfaces/IHubPeripheryFactory.sol";

import {IHubStrategyDeploymentZap} from "./interfaces/IHubStrategyDeploymentZap.sol";
import {StrategyDeploymentZapBase} from "./StrategyDeploymentZapBase.sol";

contract HubStrategyDeploymentZap is StrategyDeploymentZapBase, IHubStrategyDeploymentZap {
    /// @inheritdoc IHubStrategyDeploymentZap
    address public immutable hubCoreFactory;

    /// @inheritdoc IHubStrategyDeploymentZap
    address public immutable hubPeripheryFactory;

    constructor(address _initialOwner, address _hubCoreFactory, address _hubPeripheryFactory)
        StrategyDeploymentZapBase(_initialOwner)
    {
        hubCoreFactory = _hubCoreFactory;
        hubPeripheryFactory = _hubPeripheryFactory;
    }

    /// @inheritdoc IHubStrategyDeploymentZap
    function createMachine(CreateMachineZapParams calldata params) external returns (address) {
        address sender = msg.sender;
        bytes32 payloadHash = keccak256(msg.data);

        _consumeSchedule(sender, payloadHash);

        IMachine.MachineInitParams memory mParams = _resolvePeripheryModules(params.mParams, params.pParams);

        address machine = _deployMachine(params, mParams);

        _linkFactoryCreatedModules(params.pParams, mParams, machine);

        emit DeploymentExecuted(sender, payloadHash);

        return machine;
    }

    /// @inheritdoc IHubStrategyDeploymentZap
    function createMachineFromPreDeposit(CreateMachineFromPreDepositZapParams calldata params)
        external
        returns (address)
    {
        address sender = msg.sender;
        bytes32 payloadHash = keccak256(msg.data);

        _consumeSchedule(sender, payloadHash);

        IMachine.MachineInitParams memory mParams = _resolvePeripheryModules(params.mParams, params.pParams);

        address machine = _deployMachineFromPreDeposit(params, mParams);

        _linkFactoryCreatedModules(params.pParams, mParams, machine);

        emit DeploymentExecuted(sender, payloadHash);

        return machine;
    }

    /// @dev Deploys periphery modules via the factory and injects their addresses into mParams.
    function _resolvePeripheryModules(IMachine.MachineInitParams memory mParams, PeripheryParams calldata pParams)
        internal
        returns (IMachine.MachineInitParams memory)
    {
        if (pParams.depositorImplemId != 0) {
            if (mParams.initialDepositor != address(0)) revert ConflictingPeripheryParams();
            mParams.initialDepositor = IHubPeripheryFactory(hubPeripheryFactory)
                .createDepositor(pParams.depositorImplemId, pParams.depositorInitData);
        }
        if (pParams.redeemerImplemId != 0) {
            if (mParams.initialRedeemer != address(0)) revert ConflictingPeripheryParams();
            mParams.initialRedeemer = IHubPeripheryFactory(hubPeripheryFactory)
                .createRedeemer(pParams.redeemerImplemId, pParams.redeemerInitData);
        }
        if (pParams.feeManagerImplemId != 0) {
            if (mParams.initialFeeManager != address(0)) revert ConflictingPeripheryParams();
            mParams.initialFeeManager = IHubPeripheryFactory(hubPeripheryFactory)
                .createFeeManager(pParams.feeManagerImplemId, pParams.feeManagerInitData);
        }
        return mParams;
    }

    /// @dev Deploys a new Machine via the HubCoreFactory.
    function _deployMachine(CreateMachineZapParams calldata params, IMachine.MachineInitParams memory mParams)
        internal
        returns (address)
    {
        return IHubCoreFactory(hubCoreFactory)
            .createMachine(
                mParams,
                params.cParams,
                params.mgParams,
                params.baParams,
                params.accountingToken,
                params.tokenName,
                params.tokenSymbol,
                params.salt,
                params.setupAMFunctionRoles
            );
    }

    /// @dev Deploys a new Machine from a PreDepositVault via the HubCoreFactory.
    function _deployMachineFromPreDeposit(
        CreateMachineFromPreDepositZapParams calldata params,
        IMachine.MachineInitParams memory mParams
    ) internal returns (address) {
        return IHubCoreFactory(hubCoreFactory)
            .createMachineFromPreDeposit(
                mParams,
                params.cParams,
                params.mgParams,
                params.baParams,
                params.preDepositVault,
                params.salt,
                params.setupAMFunctionRoles
            );
    }

    /// @dev Links factory-created periphery modules to their Machine.
    function _linkFactoryCreatedModules(
        PeripheryParams calldata pParams,
        IMachine.MachineInitParams memory mParams,
        address machine
    ) internal {
        if (pParams.depositorImplemId != 0) {
            IHubPeripheryFactory(hubPeripheryFactory).setMachine(mParams.initialDepositor, machine);
        }
        if (pParams.redeemerImplemId != 0) {
            IHubPeripheryFactory(hubPeripheryFactory).setMachine(mParams.initialRedeemer, machine);
        }
        if (pParams.feeManagerImplemId != 0) {
            IHubPeripheryFactory(hubPeripheryFactory).setMachine(mParams.initialFeeManager, machine);
        }
    }
}
