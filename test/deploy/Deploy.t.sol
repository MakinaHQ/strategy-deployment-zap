// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {ICaliber} from "@makina-core/interfaces/ICaliber.sol";
import {IMachine} from "@makina-core/interfaces/IMachine.sol";
import {IPreDepositVault} from "@makina-core/interfaces/IPreDepositVault.sol";
import {Caliber} from "@makina-core/caliber/Caliber.sol";
import {Machine} from "@makina-core/machine/Machine.sol";
import {MachineShare} from "@makina-core/machine/MachineShare.sol";
import {PreDepositVault} from "@makina-core/pre-deposit/PreDepositVault.sol";
import {Roles} from "@makina-core/libraries/Roles.sol";
import {MockPriceFeed} from "@makina-core-test/mocks/MockPriceFeed.sol";

import {DeployHubStrategyDeploymentZap} from "script/deploy/DeployHubStrategyDeploymentZap.s.sol";
import {ScheduleCreateMachine} from "script/deploy/ScheduleCreateMachine.s.sol";
import {CreateMachine} from "script/deploy/CreateMachine.s.sol";
import {ScheduleCreateMachineFromPreDeposit} from "script/deploy/ScheduleCreateMachineFromPreDeposit.s.sol";
import {CreateMachineFromPreDeposit} from "script/deploy/CreateMachineFromPreDeposit.s.sol";

import {IHubStrategyDeploymentZap} from "src/interfaces/IHubStrategyDeploymentZap.sol";
import {IStrategyDeploymentZap} from "src/interfaces/IStrategyDeploymentZap.sol";

import {Integration_Concrete_Hub_Test} from "../integration/concrete/IntegrationConcrete.t.sol";

contract Deploy_Scripts_Test is Integration_Concrete_Hub_Test {
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function setUp() public virtual override {
        vm.createSelectFork({urlOrAlias: getChain(ETHEREUM_CHAIN_ID).chainAlias});

        Integration_Concrete_Hub_Test.setUp();

        MockPriceFeed usdcPriceFeed = new MockPriceFeed(18, 1e18, block.timestamp);
        MockPriceFeed wethPriceFeed = new MockPriceFeed(18, 1e18, block.timestamp);

        vm.startPrank(dao);
        oracleRegistry.setFeedRoute(USDC, address(usdcPriceFeed), DEFAULT_PF_STALE_THRSHLD, address(0), 0);
        oracleRegistry.setFeedRoute(WETH, address(wethPriceFeed), DEFAULT_PF_STALE_THRSHLD, address(0), 0);
        vm.stopPrank();
    }

    function test_LoadParamsFromEnv() public {
        string memory basePath = string.concat(vm.projectRoot(), "/script/deploy/");
        string memory filename = _testFilename();
        string memory zapOutputJson =
            vm.readFile(string.concat(basePath, "outputs/hub-strategy-deployment-zaps/", filename));

        vm.setEnv("ZAP_INPUT_FILENAME", filename);
        vm.setEnv("ZAP_OUTPUT_FILENAME", filename);
        DeployHubStrategyDeploymentZap deployZap = new DeployHubStrategyDeploymentZap();
        deployZap.loadParamsFromEnv();

        assertEq(deployZap.outputPath(), string.concat(basePath, "outputs/hub-strategy-deployment-zaps/", filename));
        assertEq(vm.parseJsonAddress(deployZap.inputJson(), ".initialOwner"), _defaultSender());

        // The machine scripts read the zap address from the zap deployment output record
        vm.setEnv("HUB_STRAT_INPUT_FILENAME", filename);
        vm.setEnv("HUB_STRAT_OUTPUT_FILENAME", filename);
        vm.setEnv("VIEW_MODE", "false");

        ScheduleCreateMachine scheduleMachine = new ScheduleCreateMachine();
        scheduleMachine.loadParamsFromEnv();

        assertFalse(scheduleMachine.viewMode());
        assertEq(scheduleMachine.zap(), vm.parseJsonAddress(zapOutputJson, ".HubStrategyDeploymentZap"));
        assertEq(scheduleMachine.outputPath(), string.concat(basePath, "outputs/create-machines/", filename));
        assertEq(vm.parseJsonAddress(scheduleMachine.inputJson(), ".executor"), _defaultSender());

        CreateMachineFromPreDeposit createFromPreDeposit = new CreateMachineFromPreDeposit();
        createFromPreDeposit.loadParamsFromEnv();

        assertEq(
            createFromPreDeposit.outputPath(),
            string.concat(basePath, "outputs/create-machines-from-pre-deposit/", filename)
        );
        assertTrue(vm.parseJsonUint(createFromPreDeposit.inputJson(), ".delay") != 0);

        // In view mode, no output record is resolved
        vm.setEnv("VIEW_MODE", "true");

        CreateMachine createMachine = new CreateMachine();
        createMachine.loadParamsFromEnv();

        assertTrue(createMachine.viewMode());
        assertEq(createMachine.outputPath(), "");
    }

    function testScript_DeployHubStrategyDeploymentZap() public {
        DeployHubStrategyDeploymentZap deployZap = _newDeployZapScript();
        deployZap.run();

        IHubStrategyDeploymentZap zap = IHubStrategyDeploymentZap(deployZap.deployedInstance());

        assertEq(Ownable(address(zap)).owner(), vm.parseJsonAddress(deployZap.inputJson(), ".initialOwner"));
        assertEq(zap.hubCoreFactory(), address(hubCoreFactory));
        assertEq(zap.hubPeripheryFactory(), address(hubPeripheryFactory));

        // Check that the deployment matches the committed record
        assertEq(
            vm.parseJsonAddress(_record("hub-strategy-deployment-zaps", _testFilename()), ".HubStrategyDeploymentZap"),
            address(zap)
        );
    }

    function testScript_DeployHubStrategyDeploymentZap_RevertWhen_AlreadyDeployed() public {
        DeployHubStrategyDeploymentZap deployZap = _newDeployZapScript();
        deployZap.run();

        address occupied = deployZap.deployedInstance();

        deployZap = _newDeployZapScript();
        vm.expectRevert(
            bytes(
                string.concat(
                    "DeployHubStrategyDeploymentZap: CREATE3 target already has code: ", vm.toString(occupied)
                )
            )
        );
        deployZap.run();
    }

    function testScript_CreateMachine() public {
        address zap = _deployZapViaScript();

        ScheduleCreateMachine scheduleMachine = new ScheduleCreateMachine();
        scheduleMachine.setParams(zap, _testFilename(), "");
        scheduleMachine.setAuthority(address(accessManager));
        scheduleMachine.run();

        skip(vm.parseJsonUint(scheduleMachine.inputJson(), ".delay"));

        CreateMachine createMachine = new CreateMachine();
        createMachine.setParams(zap, _testFilename(), "");
        createMachine.setAuthority(address(accessManager));
        createMachine.run();

        Machine machine = Machine(createMachine.deployedInstance());
        string memory inputJson = createMachine.inputJson();

        _assertMachineDeployment(
            machine,
            parseMachineInitParams(inputJson, ".machineInitParams"),
            parseCaliberInitParams(inputJson, ".caliberInitParams")
        );
        assertEq(machine.accountingToken(), vm.parseJsonAddress(inputJson, ".accountingToken"));

        MachineShare shareToken = MachineShare(machine.shareToken());
        assertEq(shareToken.name(), vm.parseJsonString(inputJson, ".shareTokenName"));
        assertEq(shareToken.symbol(), vm.parseJsonString(inputJson, ".shareTokenSymbol"));

        // Check that the deployment matches the committed record
        string memory outputJson = _record("create-machines", _testFilename());
        assertEq(vm.parseJsonAddress(outputJson, ".machine"), address(machine));
        assertEq(vm.parseJsonAddress(outputJson, ".hubCaliber"), machine.hubCaliber());
    }

    function testScript_CreateMachine_ViewMode() public {
        address zap = _deployZapViaScript();

        // View mode: the calldata is logged, the zap is never called and nothing is scheduled
        ScheduleCreateMachine scheduleMachine = new ScheduleCreateMachine();
        scheduleMachine.setParams(zap, _testFilename(), "");
        scheduleMachine.setAuthority(address(accessManager));
        scheduleMachine.setViewMode(true);

        vm.expectCall(zap, abi.encodeWithSelector(IStrategyDeploymentZap.scheduleDeployment.selector), 0);
        scheduleMachine.run();

        // Executing the unscheduled deployment reverts
        CreateMachine createMachine = new CreateMachine();
        createMachine.setParams(zap, _testFilename(), "");
        createMachine.setAuthority(address(accessManager));

        vm.expectRevert(IStrategyDeploymentZap.DeploymentNotScheduled.selector);
        createMachine.run();
    }

    function testScript_CreateMachineFromPreDeposit() public {
        address zap = _deployZapViaScript();

        // Deploy the pre-deposit vault to migrate, injected into both scripts of the variant so that they encode
        // the same payload.
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

        ScheduleCreateMachineFromPreDeposit scheduleFromPreDeposit = new ScheduleCreateMachineFromPreDeposit();
        scheduleFromPreDeposit.setParams(zap, _testFilename(), "");
        scheduleFromPreDeposit.setAuthority(address(accessManager));
        scheduleFromPreDeposit.setPreDepositVault(address(preDepositVault));
        scheduleFromPreDeposit.run();

        skip(vm.parseJsonUint(scheduleFromPreDeposit.inputJson(), ".delay"));

        CreateMachineFromPreDeposit createFromPreDeposit = new CreateMachineFromPreDeposit();
        createFromPreDeposit.setParams(zap, _testFilename(), "");
        createFromPreDeposit.setAuthority(address(accessManager));
        createFromPreDeposit.setPreDepositVault(address(preDepositVault));
        createFromPreDeposit.run();

        Machine machine = Machine(createFromPreDeposit.deployedInstance());

        // Check that the deployment matches the committed record
        assertEq(
            vm.parseJsonAddress(_record("create-machines-from-pre-deposit", _testFilename()), ".machine"),
            address(machine)
        );
        string memory inputJson = createFromPreDeposit.inputJson();

        _assertMachineDeployment(
            machine,
            parseMachineInitParams(inputJson, ".machineInitParams"),
            parseCaliberInitParams(inputJson, ".caliberInitParams")
        );

        // Accounting token and share token ownership are migrated from the vault.
        assertEq(machine.accountingToken(), address(accountingToken));
        assertEq(machine.shareToken(), shareToken);
    }

    ///
    /// HELPERS
    ///

    /// @dev The address forge broadcasts from in these tests, i.e. the zap owner and the deployment executor.
    function _defaultSender() internal pure returns (address) {
        return 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
    }

    /// @dev Test record filename of this fork's chain.
    function _testFilename() internal returns (string memory) {
        return string.concat(getChain(ETHEREUM_CHAIN_ID).name, "-Test.json");
    }

    /// @dev The zap deployment script, with the factories deployed by `setUp` injected. No output record is written.
    function _newDeployZapScript() internal returns (DeployHubStrategyDeploymentZap deployZap) {
        deployZap = new DeployHubStrategyDeploymentZap();
        deployZap.setFilenames(_testFilename(), "");
        deployZap.setFactories(address(hubCoreFactory), address(hubPeripheryFactory));
    }

    /// @dev Runs the zap deployment script and grants the deployed zap the strategy deployment role.
    function _deployZapViaScript() internal returns (address zap) {
        DeployHubStrategyDeploymentZap deployZap = _newDeployZapScript();
        deployZap.run();
        zap = deployZap.deployedInstance();

        vm.prank(dao);
        accessManager.grantRole(Roles.STRATEGY_DEPLOYMENT_ROLE, zap, 0);
    }

    function _assertMachineDeployment(
        Machine machine,
        IMachine.MachineInitParams memory mParams,
        ICaliber.CaliberInitParams memory cParams
    ) internal view {
        assertTrue(hubCoreFactory.isMachine(address(machine)));

        assertEq(machine.caliberStaleThreshold(), mParams.initialCaliberStaleThreshold);
        assertEq(machine.maxFixedFeeAccrualRate(), mParams.initialMaxFixedFeeAccrualRate);
        assertEq(machine.maxPerfFeeAccrualRate(), mParams.initialMaxPerfFeeAccrualRate);
        assertEq(machine.feeMintCooldown(), mParams.initialFeeMintCooldown);
        assertEq(machine.shareLimit(), mParams.initialShareLimit);
        assertEq(machine.maxSharePriceChangeRate(), mParams.initialMaxSharePriceChangeRate);

        assertEq(machine.mechanic(), mechanic);
        assertEq(machine.securityCouncil(), securityCouncil);
        assertEq(machine.riskManager(), riskManager);
        assertEq(machine.riskManagerTimelock(), riskManagerTimelock);
        assertEq(machine.authority(), address(accessManager));
        assertFalse(machine.restrictedAccountingMode());

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

    /// @dev A committed test record under `outputs/`. Test deployments are deterministic, so they match the records
    ///      without rewriting them. A failing comparison means the record must be regenerated, by running the
    ///      script with that output filename.
    function _record(string memory dir, string memory filename) internal view returns (string memory) {
        return vm.readFile(string.concat(vm.projectRoot(), "/script/deploy/outputs/", dir, "/", filename));
    }
}
