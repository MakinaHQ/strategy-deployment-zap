// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {ICaliber} from "@makina-core/interfaces/ICaliber.sol";
import {IMachine} from "@makina-core/interfaces/IMachine.sol";
import {IMakinaGovernable} from "@makina-core/interfaces/IMakinaGovernable.sol";
import {IPreDepositVault} from "@makina-core/interfaces/IPreDepositVault.sol";
import {Caliber} from "@makina-core/caliber/Caliber.sol";
import {Machine} from "@makina-core/machine/Machine.sol";
import {MachineShare} from "@makina-core/machine/MachineShare.sol";
import {PreDepositVault} from "@makina-core/pre-deposit/PreDepositVault.sol";
import {Roles} from "@makina-core/libraries/Roles.sol";

import {DeployHubStrategyDeploymentZap} from "script/deployments/DeployHubStrategyDeploymentZap.s.sol";
import {ScheduleCreateMachine} from "script/deployments/ScheduleCreateMachine.s.sol";
import {CreateMachine} from "script/deployments/CreateMachine.s.sol";
import {ScheduleCreateMachineFromPreDeposit} from "script/deployments/ScheduleCreateMachineFromPreDeposit.s.sol";
import {CreateMachineFromPreDeposit} from "script/deployments/CreateMachineFromPreDeposit.s.sol";

import {IHubStrategyDeploymentZap} from "src/interfaces/IHubStrategyDeploymentZap.sol";

import {Integration_Concrete_Hub_Test} from "../integration/concrete/IntegrationConcrete.t.sol";

contract Deploy_Scripts_Test is Integration_Concrete_Hub_Test {
    // References the contract addresses deployed by `setUp`
    string internal constant FILE = "Test.json";

    function setUp() public virtual override {
        Integration_Concrete_Hub_Test.setUp();

        vm.setEnv("ZAP_INPUT_FILENAME", FILE);
        vm.setEnv("ZAP_OUTPUT_FILENAME", FILE);
        vm.setEnv("HUB_STRAT_INPUT_FILENAME", FILE);
        vm.setEnv("HUB_STRAT_OUTPUT_FILENAME", FILE);
    }

    function testScript_DeployHubStrategyDeploymentZap() public {
        DeployHubStrategyDeploymentZap deployZap = new DeployHubStrategyDeploymentZap();
        deployZap.run();

        IHubStrategyDeploymentZap zap = IHubStrategyDeploymentZap(deployZap.deployedInstance());
        string memory inputJson = deployZap.inputJson();

        assertEq(Ownable(address(zap)).owner(), vm.parseJsonAddress(inputJson, ".initialOwner"));
        assertEq(zap.hubCoreFactory(), vm.parseJsonAddress(inputJson, ".hubCoreFactory"));
        assertEq(zap.hubPeripheryFactory(), vm.parseJsonAddress(inputJson, ".hubPeripheryFactory"));
    }

    function testScript_CreateMachine() public {
        _ensureDir("outputs/create-machines");

        _deployZapViaScript();

        ScheduleCreateMachine scheduleMachine = new ScheduleCreateMachine();
        scheduleMachine.run();

        skip(vm.parseJsonUint(scheduleMachine.inputJson(), ".delay"));

        CreateMachine createMachine = new CreateMachine();
        createMachine.run();
        Machine machine = Machine(createMachine.deployedInstance());
        string memory inputJson = createMachine.inputJson();

        _assertMachineDeployment(
            machine,
            parseMachineInitParams(inputJson, ".machineInitParams"),
            parseCaliberInitParams(inputJson, ".caliberInitParams"),
            parseMakinaGovernableInitParams(inputJson, ".makinaGovernableInitParams")
        );
        assertEq(machine.accountingToken(), vm.parseJsonAddress(inputJson, ".accountingToken"));

        MachineShare shareToken = MachineShare(machine.shareToken());
        assertEq(shareToken.name(), vm.parseJsonString(inputJson, ".shareTokenName"));
        assertEq(shareToken.symbol(), vm.parseJsonString(inputJson, ".shareTokenSymbol"));
    }

    function testScript_CreateMachineFromPreDeposit() public {
        _ensureDir("outputs/create-machines-from-pre-deposit");

        _deployZapViaScript();

        // Deploy the pre-deposit vault referenced by the input file.
        vm.prank(dao);
        accessManager.grantRole(Roles.STRATEGY_DEPLOYMENT_ROLE, address(this), 0);
        PreDepositVault preDepositVault = PreDepositVault(
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
        address shareToken = preDepositVault.shareToken();

        ScheduleCreateMachineFromPreDeposit scheduleFromPd = new ScheduleCreateMachineFromPreDeposit();
        assertEq(vm.parseJsonAddress(scheduleFromPd.inputJson(), ".preDepositVault"), address(preDepositVault));
        scheduleFromPd.run();

        skip(vm.parseJsonUint(scheduleFromPd.inputJson(), ".delay"));

        CreateMachineFromPreDeposit createFromPd = new CreateMachineFromPreDeposit();
        createFromPd.run();
        Machine machine = Machine(createFromPd.deployedInstance());
        string memory inputJson = createFromPd.inputJson();

        _assertMachineDeployment(
            machine,
            parseMachineInitParams(inputJson, ".machineInitParams"),
            parseCaliberInitParams(inputJson, ".caliberInitParams"),
            parseMakinaGovernableInitParams(inputJson, ".makinaGovernableInitParams")
        );

        // Accounting token and share token ownership are migrated from the vault.
        assertEq(machine.accountingToken(), address(accountingToken));
        assertEq(machine.shareToken(), shareToken);
    }

    ///
    /// HELPERS
    ///

    /// @dev Runs the zap deployment script and grants the deployed zap the strategy deployment role. The zap
    ///      address is written to the zap output file, which the schedule/execute scripts read back.
    function _deployZapViaScript() internal {
        DeployHubStrategyDeploymentZap deployZap = new DeployHubStrategyDeploymentZap();
        deployZap.run();
        address zap = deployZap.deployedInstance();

        vm.prank(dao);
        accessManager.grantRole(Roles.STRATEGY_DEPLOYMENT_ROLE, zap, 0);
    }

    function _assertMachineDeployment(
        Machine machine,
        IMachine.MachineInitParams memory mParams,
        ICaliber.CaliberInitParams memory cParams,
        IMakinaGovernable.MakinaGovernableInitParams memory mgParams
    ) internal view {
        assertTrue(hubCoreFactory.isMachine(address(machine)));

        assertEq(machine.caliberStaleThreshold(), mParams.initialCaliberStaleThreshold);
        assertEq(machine.maxFixedFeeAccrualRate(), mParams.initialMaxFixedFeeAccrualRate);
        assertEq(machine.maxPerfFeeAccrualRate(), mParams.initialMaxPerfFeeAccrualRate);
        assertEq(machine.feeMintCooldown(), mParams.initialFeeMintCooldown);
        assertEq(machine.shareLimit(), mParams.initialShareLimit);
        assertEq(machine.maxSharePriceChangeRate(), mParams.initialMaxSharePriceChangeRate);

        assertEq(machine.mechanic(), mgParams.initialMechanic);
        assertEq(machine.securityCouncil(), mgParams.initialSecurityCouncil);
        assertEq(machine.riskManager(), mgParams.initialRiskManager);
        assertEq(machine.riskManagerTimelock(), mgParams.initialRiskManagerTimelock);
        assertEq(machine.authority(), mgParams.initialAuthority);
        assertEq(machine.restrictedAccountingMode(), mgParams.initialRestrictedAccountingMode);

        Caliber caliber = Caliber(machine.hubCaliber());
        assertTrue(hubCoreFactory.isCaliber(address(caliber)));
        assertEq(caliber.hubMachineEndpoint(), address(machine));
        assertEq(caliber.positionStaleThreshold(), cParams.initialPositionStaleThreshold);
        assertEq(caliber.allowedInstrRoot(), cParams.initialAllowedInstrRoot);
        assertEq(caliber.timelockDuration(), cParams.initialTimelockDuration);
        assertEq(caliber.maxPositionIncreaseLossBps(), cParams.initialMaxPositionIncreaseLossBps);
        assertEq(caliber.maxPositionDecreaseLossBps(), cParams.initialMaxPositionDecreaseLossBps);
        assertEq(caliber.maxSwapLossBps(), cParams.initialMaxSwapLossBps);
        assertEq(caliber.cooldownDuration(), cParams.initialCooldownDuration);
    }

    function _ensureDir(string memory subDir) internal {
        string memory path = string.concat(vm.projectRoot(), "/script/deployments/", subDir);
        if (!vm.exists(path)) {
            vm.createDir(path, true);
        }
    }
}
