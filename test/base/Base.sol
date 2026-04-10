// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {
    AccessManagerUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";

import {Roles} from "@makina-core/libraries/Roles.sol";

import {HubStrategyDeploymentZap} from "../../src/HubStrategyDeploymentZap.sol";

abstract contract Base {
    function deployHubStrategyDeploymentZap(address initialOwner, address hubCoreFactory, address hubPeripheryFactory)
        public
        returns (HubStrategyDeploymentZap)
    {
        return new HubStrategyDeploymentZap(initialOwner, hubCoreFactory, hubPeripheryFactory);
    }

    function setupAccessManagerStrategyDeploymentZapRoles(
        AccessManagerUpgradeable accessManager,
        address strategyDeploymentZap
    ) public {
        accessManager.grantRole(Roles.STRATEGY_DEPLOYMENT_ROLE, strategyDeploymentZap, 0);
    }
}

