// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";

import {
    AccessManagerUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";

import "@makina-core-test/base/Base.sol" as Core_base;
import "@makina-core-test/utils/Constants.sol" as Core_Constants;

import "@makina-periphery-test/base/Base.sol" as Periphery_base;
import "@makina-periphery-test/utils/Constants.sol" as Periphery_Constants;

import {HubCoreRegistry} from "@makina-core/registries/HubCoreRegistry.sol";
import {HubCoreFactory} from "@makina-core/factories/HubCoreFactory.sol";
import {OracleRegistry} from "@makina-core/registries/OracleRegistry.sol";
import {Roles} from "@makina-core/libraries/Roles.sol";

import {HubPeripheryRegistry} from "@makina-periphery/registries/HubPeripheryRegistry.sol";
import {HubPeripheryFactory} from "@makina-periphery/factories/HubPeripheryFactory.sol";

import {HubStrategyDeploymentZap} from "../../src/HubStrategyDeploymentZap.sol";

import {Base} from "./Base.sol";

abstract contract Base_Test is
    Base,
    Test,
    Core_base.Base,
    Core_Constants.Constants,
    Periphery_base.Base,
    Periphery_Constants.Constants
{
    address public deployer;

    uint256 public hubChainId;

    address public dao;
    address public mechanic;
    address public securityCouncil;
    address public riskManager;
    address public riskManagerTimelock;

    // Core
    AccessManagerUpgradeable public accessManager;
    OracleRegistry public oracleRegistry;

    function setUp() public virtual {
        deployer = address(this);
        dao = makeAddr("MakinaDAO");
        mechanic = makeAddr("Mechanic");
        securityCouncil = makeAddr("SecurityCouncil");
        riskManager = makeAddr("RiskManager");
        riskManagerTimelock = makeAddr("RiskManagerTimelock");
    }

    function _deployWeirollVM() internal pure override returns (address) {
        return address(0);
    }

    function setupAccessManagerRoles(address coreFactory, address strategyDeploymentZap) public {
        // Grant relevant roles to zap
        setupAccessManagerStrategyDeploymentZapRoles(accessManager, strategyDeploymentZap);

        // Grant roles to the relevant contracts and accounts
        accessManager.grantRole(accessManager.ADMIN_ROLE(), coreFactory, 0);
        accessManager.grantRole(accessManager.ADMIN_ROLE(), dao, 0);
        accessManager.grantRole(Roles.INFRA_CONFIG_ROLE, dao, 0);
        accessManager.grantRole(Roles.STRATEGY_DEPLOYMENT_ROLE, dao, 0);
        accessManager.grantRole(Roles.STRATEGY_COMPONENTS_LINKING_ROLE, dao, 0);
        accessManager.grantRole(Roles.STRATEGY_MANAGEMENT_CONFIG_ROLE, dao, 0);

        // Revoke roles from the deployer
        accessManager.revokeRole(accessManager.ADMIN_ROLE(), address(deployer));
    }

    function transferAccessManagerOwnership() public {
        bytes32 ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
        address proxyAdmin = address(uint160(uint256(vm.load(address(accessManager), ADMIN_SLOT))));
        Ownable(proxyAdmin).transferOwnership(address(accessManager));
    }
}

abstract contract Base_Hub_Test is Base_Test {
    // Hub Core
    HubCoreRegistry public hubCoreRegistry;
    HubCoreFactory public hubCoreFactory;
    UpgradeableBeacon public caliberBeacon;
    UpgradeableBeacon public machineBeacon;
    UpgradeableBeacon public preDepositVaultBeacon;

    // Hub Periphery
    HubPeripheryRegistry public hubPeripheryRegistry;
    HubPeripheryFactory public hubPeripheryFactory;
    UpgradeableBeacon public directDepositorBeacon;
    UpgradeableBeacon public asyncRedeemerBeacon;
    UpgradeableBeacon public watermarkFeeManagerBeacon;

    // Zap
    HubStrategyDeploymentZap public hubStrategyDeploymentZap;

    function setUp() public virtual override {
        Base_Test.setUp();
        hubChainId = block.chainid;

        FlashloanProviders memory flp;

        // Hub Core
        Core_base.Base.HubCore memory hubCore = deployHubCore(deployer, address(0));
        accessManager = hubCore.accessManager;
        oracleRegistry = hubCore.oracleRegistry;
        hubCoreRegistry = hubCore.hubCoreRegistry;
        hubCoreFactory = hubCore.hubCoreFactory;
        caliberBeacon = hubCore.caliberBeacon;
        machineBeacon = hubCore.machineBeacon;
        preDepositVaultBeacon = hubCore.preDepositVaultBeacon;

        hubCoreRegistry.setCoreFactory(address(hubCoreFactory));
        hubCoreRegistry.setCaliberBeacon(address(caliberBeacon));
        hubCoreRegistry.setMachineBeacon(address(machineBeacon));
        hubCoreRegistry.setPreDepositVaultBeacon(address(preDepositVaultBeacon));

        // Hub Periphery
        Periphery_base.Base.HubPeriphery memory hubPeriphery =
            deployHubPeriphery(address(accessManager), address(hubCoreRegistry), flp);
        hubPeripheryRegistry = hubPeriphery.hubPeripheryRegistry;
        hubPeripheryFactory = hubPeriphery.hubPeripheryFactory;
        directDepositorBeacon = hubPeriphery.directDepositorBeacon;
        asyncRedeemerBeacon = hubPeriphery.asyncRedeemerBeacon;
        watermarkFeeManagerBeacon = hubPeriphery.watermarkFeeManagerBeacon;

        registerHubPeripheryFactory(address(hubPeripheryRegistry), address(hubPeripheryFactory));

        uint16[] memory mdImplemIds = new uint16[](1);
        mdImplemIds[0] = DIRECT_DEPOSITOR_IMPLEM_ID;
        address[] memory mdBeacons = new address[](1);
        mdBeacons[0] = address(hubPeriphery.directDepositorBeacon);
        registerDepositorBeacons(address(hubPeripheryRegistry), mdImplemIds, mdBeacons);

        uint16[] memory mrImplemIds = new uint16[](1);
        mrImplemIds[0] = ASYNC_REDEEMER_IMPLEM_ID;
        address[] memory mrBeacons = new address[](1);
        mrBeacons[0] = address(hubPeriphery.asyncRedeemerBeacon);
        registerRedeemerBeacons(address(hubPeripheryRegistry), mrImplemIds, mrBeacons);

        uint16[] memory fmImplemIds = new uint16[](1);
        fmImplemIds[0] = WATERMARK_FEE_MANAGER_IMPLEM_ID;
        address[] memory fmBeacons = new address[](1);
        fmBeacons[0] = address(hubPeriphery.watermarkFeeManagerBeacon);
        registerFeeManagerBeacons(address(hubPeripheryRegistry), fmImplemIds, fmBeacons);

        setupHubCoreAMFunctionRoles(hubCore);
        setupHubPeripheryAMFunctionRoles(address(accessManager), hubPeriphery);

        // Zap
        hubStrategyDeploymentZap =
            new HubStrategyDeploymentZap(dao, address(hubCoreFactory), address(hubPeripheryFactory));

        setupAccessManagerRoles(address(hubCoreFactory), address(hubStrategyDeploymentZap));
        transferAccessManagerOwnership();
    }
}
