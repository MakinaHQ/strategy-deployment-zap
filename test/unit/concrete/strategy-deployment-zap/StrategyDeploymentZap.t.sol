// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IStrategyDeploymentZap} from "src/interfaces/IStrategyDeploymentZap.sol";

import {Base_Test} from "../../../base/Base.t.sol";

abstract contract StrategyDeploymentZap_Unit_Concrete_Test is Base_Test {
    IStrategyDeploymentZap public strategyDeploymentZap;
}
