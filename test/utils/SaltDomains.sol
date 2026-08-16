// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

abstract contract SaltDomains {
    /// @dev HubStrategyDeploymentZap is non-upgradeable, so its salt domain is versioned.
    bytes32 internal constant HUB_STRATEGY_DEPLOYMENT_ZAP_SALT_DOMAIN =
        keccak256("makina.salt.HubStrategyDeploymentZap.v1.3.0");
}
