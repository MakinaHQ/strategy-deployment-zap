// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {
    AccessManagerUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";

import "@makina-core-test/base/Base.sol" as Core_base;
import {Roles} from "@makina-core/libraries/Roles.sol";

import "@makina-periphery-test/base/Base.sol" as Periphery_base;

import {HubStrategyDeploymentZap} from "../../src/HubStrategyDeploymentZap.sol";
import {SaltDomains} from "../utils/SaltDomains.sol";

abstract contract Base is SaltDomains, Core_base.Base, Periphery_base.Base {
    function deployHubStrategyDeploymentZap(address initialOwner, address hubCoreFactory, address hubPeripheryFactory)
        public
        returns (HubStrategyDeploymentZap)
    {
        return HubStrategyDeploymentZap(
            _deployCode(
                abi.encodePacked(
                    type(HubStrategyDeploymentZap).creationCode,
                    abi.encode(initialOwner, hubCoreFactory, hubPeripheryFactory)
                ),
                HUB_STRATEGY_DEPLOYMENT_ZAP_SALT_DOMAIN
            )
        );
    }

    function setupAccessManagerStrategyDeploymentZapRoles(
        AccessManagerUpgradeable accessManager,
        address strategyDeploymentZap
    ) public {
        accessManager.grantRole(Roles.STRATEGY_DEPLOYMENT_ROLE, strategyDeploymentZap, 0);
    }
}
