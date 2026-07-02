// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IBridgeAdapterFactory} from "@makina-core/interfaces/IBridgeAdapterFactory.sol";
import {ICaliber} from "@makina-core/interfaces/ICaliber.sol";
import {Caliber} from "@makina-core/caliber/Caliber.sol";
import {IMachine} from "@makina-core/interfaces/IMachine.sol";
import {IMakinaGovernable} from "@makina-core/interfaces/IMakinaGovernable.sol";
import {IPreDepositVault} from "@makina-core/interfaces/IPreDepositVault.sol";
import {ISpokeSnapshotConsumer} from "@makina-core/interfaces/ISpokeSnapshotConsumer.sol";
import {Machine} from "@makina-core/machine/Machine.sol";
import {PreDepositVault} from "@makina-core/pre-deposit/PreDepositVault.sol";
import {Roles} from "@makina-core/libraries/Roles.sol";

import {IHubPeripheryFactory} from "@makina-periphery/interfaces/IHubPeripheryFactory.sol";
import {IWatermarkFeeManager} from "@makina-periphery/interfaces/IWatermarkFeeManager.sol";

import {IStrategyDeploymentZap} from "src/interfaces/IStrategyDeploymentZap.sol";
import {IHubStrategyDeploymentZap} from "src/interfaces/IHubStrategyDeploymentZap.sol";

import {Integration_Concrete_Hub_Test} from "../../IntegrationConcrete.t.sol";

contract CreateMachineFromPreDeposit_Integration_Concrete_Test is Integration_Concrete_Hub_Test {
    function test_RevertGiven_DeploymentNotScheduled() public {
        IHubStrategyDeploymentZap.CreateMachineFromPreDepositZapParams memory param;

        vm.expectRevert(IStrategyDeploymentZap.DeploymentNotScheduled.selector);
        hubStrategyDeploymentZap.createMachineFromPreDeposit(param);
    }

    function test_RevertGiven_DeploymentNotReady() public {
        IHubStrategyDeploymentZap.CreateMachineFromPreDepositZapParams memory param;

        vm.prank(dao);
        hubStrategyDeploymentZap.scheduleDeployment(
            address(this), abi.encodeCall(IHubStrategyDeploymentZap.createMachineFromPreDeposit, (param)), scheduleDelay
        );

        vm.expectRevert(IStrategyDeploymentZap.DeploymentNotReady.selector);
        hubStrategyDeploymentZap.createMachineFromPreDeposit(param);
    }

    function test_RevertWhen_ConflictingDepositorParams() public {
        PreDepositVault preDepositVault = _deployPreDepositVault();
        IHubStrategyDeploymentZap.CreateMachineFromPreDepositZapParams memory param =
            _defaultCreateMachineFromPreDepositZapParams(address(preDepositVault));
        param.mParams.initialDepositor = makeAddr("existingDepositor");

        _schedule(param);
        skip(scheduleDelay);

        vm.expectRevert(IHubStrategyDeploymentZap.ConflictingPeripheryParams.selector);
        hubStrategyDeploymentZap.createMachineFromPreDeposit(param);
    }

    function test_RevertWhen_ConflictingRedeemerParams() public {
        PreDepositVault preDepositVault = _deployPreDepositVault();
        IHubStrategyDeploymentZap.CreateMachineFromPreDepositZapParams memory param =
            _defaultCreateMachineFromPreDepositZapParams(address(preDepositVault));
        param.mParams.initialRedeemer = makeAddr("existingRedeemer");

        _schedule(param);
        skip(scheduleDelay);

        vm.expectRevert(IHubStrategyDeploymentZap.ConflictingPeripheryParams.selector);
        hubStrategyDeploymentZap.createMachineFromPreDeposit(param);
    }

    function test_RevertWhen_ConflictingFeeManagerParams() public {
        PreDepositVault preDepositVault = _deployPreDepositVault();
        IHubStrategyDeploymentZap.CreateMachineFromPreDepositZapParams memory param =
            _defaultCreateMachineFromPreDepositZapParams(address(preDepositVault));
        param.mParams.initialFeeManager = makeAddr("existingFeeManager");

        _schedule(param);
        skip(scheduleDelay);

        vm.expectRevert(IHubStrategyDeploymentZap.ConflictingPeripheryParams.selector);
        hubStrategyDeploymentZap.createMachineFromPreDeposit(param);
    }

    function test_CreateMachineFromPreDeposit() public {
        PreDepositVault preDepositVault = _deployPreDepositVault();
        address shareToken = preDepositVault.shareToken();

        IHubStrategyDeploymentZap.CreateMachineFromPreDepositZapParams memory param =
            _defaultCreateMachineFromPreDepositZapParams(address(preDepositVault));

        bytes memory payload = abi.encodeCall(IHubStrategyDeploymentZap.createMachineFromPreDeposit, (param));

        vm.prank(dao);
        hubStrategyDeploymentZap.scheduleDeployment(address(this), payload, scheduleDelay);

        skip(scheduleDelay);

        vm.expectEmit(false, true, false, false, address(hubPeripheryFactory));
        emit IHubPeripheryFactory.DepositorCreated(address(0), DIRECT_DEPOSITOR_IMPLEM_ID);

        vm.expectEmit(false, true, false, false, address(hubPeripheryFactory));
        emit IHubPeripheryFactory.RedeemerCreated(address(0), ASYNC_REDEEMER_IMPLEM_ID);

        vm.expectEmit(false, true, false, false, address(hubPeripheryFactory));
        emit IHubPeripheryFactory.FeeManagerCreated(address(0), WATERMARK_FEE_MANAGER_IMPLEM_ID);

        vm.expectEmit(true, true, false, false, address(hubStrategyDeploymentZap));
        emit IStrategyDeploymentZap.DeploymentExecuted(address(this), keccak256(payload));
        Machine machine = Machine(hubStrategyDeploymentZap.createMachineFromPreDeposit(param));

        assertEq(machine.accountingToken(), address(accountingToken));
        assertEq(machine.caliberStaleThreshold(), DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD);
        assertEq(machine.maxFixedFeeAccrualRate(), DEFAULT_MACHINE_MAX_FIXED_FEE_ACCRUAL_RATE);
        assertEq(machine.maxPerfFeeAccrualRate(), DEFAULT_MACHINE_MAX_PERF_FEE_ACCRUAL_RATE);
        assertEq(machine.feeMintCooldown(), DEFAULT_MACHINE_FEE_MINT_COOLDOWN);
        assertEq(machine.shareLimit(), DEFAULT_MACHINE_SHARE_LIMIT);
        assertEq(machine.maxSharePriceChangeRate(), DEFAULT_MACHINE_MAX_SHARE_PRICE_CHANGE_RATE);

        assertEq(machine.mechanic(), mechanic);
        assertEq(machine.securityCouncil(), securityCouncil);
        assertEq(machine.riskManager(), riskManager);
        assertEq(machine.riskManagerTimelock(), riskManagerTimelock);
        assertEq(machine.authority(), address(accessManager));
        assertFalse(machine.restrictedAccountingMode());
        assertTrue(machine.isAccountingAgent(accountingAgent));

        assertEq(machine.shareToken(), shareToken);

        Caliber caliber = Caliber(machine.hubCaliber());
        assertEq(caliber.positionStaleThreshold(), DEFAULT_CALIBER_POS_STALE_THRESHOLD);
        assertEq(caliber.allowedInstrRoot(), bytes32(0));
        assertEq(caliber.timelockDuration(), DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK);
        assertEq(caliber.maxPositionIncreaseLossBps(), DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS);
        assertEq(caliber.maxPositionDecreaseLossBps(), DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS);
        assertEq(caliber.maxSwapLossBps(), DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS);
        assertEq(caliber.cooldownDuration(), DEFAULT_CALIBER_COOLDOWN_DURATION);
        assertEq(caliber.getBaseTokensLength(), 2);
        assertEq(caliber.getBaseToken(1), address(baseToken));
    }

    function test_CreateMachineFromPreDeposit_WithPreExistingDepositorAndRedeemer() public {
        PreDepositVault preDepositVault = _deployPreDepositVault();

        IHubStrategyDeploymentZap.CreateMachineFromPreDepositZapParams memory param =
            _defaultCreateMachineFromPreDepositZapParams(address(preDepositVault));

        address existingDepositor = makeAddr("existingDepositor");
        address existingRedeemer = makeAddr("existingRedeemer");

        param.pParams.depositorImplemId = 0;
        param.pParams.depositorInitData = "";
        param.pParams.redeemerImplemId = 0;
        param.pParams.redeemerInitData = "";
        param.mParams.initialDepositor = existingDepositor;
        param.mParams.initialRedeemer = existingRedeemer;
        param.salt = bytes32(uint256(TEST_DEPLOYMENT_SALT) + 1);

        bytes memory payload = abi.encodeCall(IHubStrategyDeploymentZap.createMachineFromPreDeposit, (param));

        vm.prank(dao);
        hubStrategyDeploymentZap.scheduleDeployment(address(this), payload, scheduleDelay);

        skip(scheduleDelay);

        vm.expectEmit(false, true, false, false, address(hubPeripheryFactory));
        emit IHubPeripheryFactory.FeeManagerCreated(address(0), WATERMARK_FEE_MANAGER_IMPLEM_ID);

        vm.expectEmit(true, true, false, false, address(hubStrategyDeploymentZap));
        emit IStrategyDeploymentZap.DeploymentExecuted(address(this), keccak256(payload));
        Machine machine = Machine(hubStrategyDeploymentZap.createMachineFromPreDeposit(param));

        assertEq(machine.depositor(), existingDepositor);
        assertEq(machine.redeemer(), existingRedeemer);
        assertNotEq(machine.feeManager(), address(0));
    }

    function _deployPreDepositVault() internal returns (PreDepositVault) {
        vm.prank(dao);
        accessManager.grantRole(Roles.STRATEGY_DEPLOYMENT_ROLE, address(this), 0);
        return PreDepositVault(
            hubCoreFactory.createPreDepositVault(
                IPreDepositVault.PreDepositVaultInitParams({
                    initialShareLimit: 0,
                    initialWhitelistMode: false,
                    initialRiskManager: address(0),
                    initialAuthority: address(0)
                }),
                address(baseToken),
                address(accountingToken),
                DEFAULT_MACHINE_SHARE_TOKEN_NAME,
                DEFAULT_MACHINE_SHARE_TOKEN_SYMBOL,
                false
            )
        );
    }

    function _defaultPeripheryParams() internal view returns (IHubStrategyDeploymentZap.PeripheryParams memory) {
        uint256[] memory dummyFeeSplitBps = new uint256[](1);
        dummyFeeSplitBps[0] = 10_000;
        address[] memory dummyFeeSplitReceivers = new address[](1);
        dummyFeeSplitReceivers[0] = dao;

        return IHubStrategyDeploymentZap.PeripheryParams({
            depositorImplemId: DIRECT_DEPOSITOR_IMPLEM_ID,
            redeemerImplemId: ASYNC_REDEEMER_IMPLEM_ID,
            feeManagerImplemId: WATERMARK_FEE_MANAGER_IMPLEM_ID,
            depositorInitData: abi.encode(DEFAULT_INITIAL_WHITELIST_STATUS, false),
            redeemerInitData: abi.encode(
                DEFAULT_FINALIZATION_DELAY, DEFAULT_MIN_REDEEM_AMOUNT, DEFAULT_INITIAL_WHITELIST_STATUS, false
            ),
            feeManagerInitData: abi.encode(
                IWatermarkFeeManager.WatermarkFeeManagerInitParams({
                    initialMgmtFeeRatePerSecond: DEFAULT_WATERMARK_FEE_MANAGER_MGMT_FEE_RATE_PER_SECOND,
                    initialSmFeeRatePerSecond: DEFAULT_WATERMARK_FEE_MANAGER_SM_FEE_RATE_PER_SECOND,
                    initialPerfFeeRate: DEFAULT_WATERMARK_FEE_MANAGER_PERF_FEE_RATE,
                    initialMgmtFeeSplitBps: dummyFeeSplitBps,
                    initialMgmtFeeReceivers: dummyFeeSplitReceivers,
                    initialPerfFeeSplitBps: dummyFeeSplitBps,
                    initialPerfFeeReceivers: dummyFeeSplitReceivers
                })
            )
        });
    }

    function _defaultCreateMachineFromPreDepositZapParams(address preDepositVault)
        internal
        view
        returns (IHubStrategyDeploymentZap.CreateMachineFromPreDepositZapParams memory)
    {
        address[] memory initialBaseTokens = new address[](1);
        initialBaseTokens[0] = address(baseToken);

        address[] memory initialAccountingAgents = new address[](1);
        initialAccountingAgents[0] = accountingAgent;

        bytes32[] memory initialCreWorkflowIds = new bytes32[](1);
        initialCreWorkflowIds[0] = DEFAULT_CRE_WORKFLOW_ID;

        return IHubStrategyDeploymentZap.CreateMachineFromPreDepositZapParams({
            pParams: _defaultPeripheryParams(),
            mParams: IMachine.MachineInitParams({
                initialDepositor: address(0),
                initialRedeemer: address(0),
                initialFeeManager: address(0),
                initialCaliberStaleThreshold: DEFAULT_MACHINE_CALIBER_STALE_THRESHOLD,
                initialMaxFixedFeeAccrualRate: DEFAULT_MACHINE_MAX_FIXED_FEE_ACCRUAL_RATE,
                initialMaxPerfFeeAccrualRate: DEFAULT_MACHINE_MAX_PERF_FEE_ACCRUAL_RATE,
                initialFeeMintCooldown: DEFAULT_MACHINE_FEE_MINT_COOLDOWN,
                initialShareLimit: DEFAULT_MACHINE_SHARE_LIMIT,
                initialMaxSharePriceChangeRate: DEFAULT_MACHINE_MAX_SHARE_PRICE_CHANGE_RATE
            }),
            cParams: ICaliber.CaliberInitParams({
                initialPositionStaleThreshold: DEFAULT_CALIBER_POS_STALE_THRESHOLD,
                initialAllowedInstrRoot: bytes32(0),
                initialTimelockDuration: DEFAULT_CALIBER_ROOT_UPDATE_TIMELOCK,
                initialMaxPositionIncreaseLossBps: DEFAULT_CALIBER_MAX_POS_INCREASE_LOSS_BPS,
                initialMaxPositionDecreaseLossBps: DEFAULT_CALIBER_MAX_POS_DECREASE_LOSS_BPS,
                initialMaxSwapLossBps: DEFAULT_CALIBER_MAX_SWAP_LOSS_BPS,
                initialCooldownDuration: DEFAULT_CALIBER_COOLDOWN_DURATION,
                initialBaseTokens: initialBaseTokens
            }),
            mgParams: IMakinaGovernable.MakinaGovernableInitParams({
                initialMechanic: mechanic,
                initialSecurityCouncil: securityCouncil,
                initialRiskManager: riskManager,
                initialRiskManagerTimelock: riskManagerTimelock,
                initialAuthority: address(accessManager),
                initialRestrictedAccountingMode: false,
                initialAccountingAgents: initialAccountingAgents
            }),
            sscParams: ISpokeSnapshotConsumer.SpokeSnapshotConsumerInitParams({
                initialCreWorkflowIds: initialCreWorkflowIds
            }),
            baParams: new IBridgeAdapterFactory.BridgeAdapterInitParams[](0),
            preDepositVault: preDepositVault,
            salt: TEST_DEPLOYMENT_SALT,
            setupAMFunctionRoles: true
        });
    }

    function _schedule(IHubStrategyDeploymentZap.CreateMachineFromPreDepositZapParams memory param) internal {
        vm.prank(dao);
        hubStrategyDeploymentZap.scheduleDeployment(
            address(this), abi.encodeCall(IHubStrategyDeploymentZap.createMachineFromPreDeposit, (param)), scheduleDelay
        );
    }
}
