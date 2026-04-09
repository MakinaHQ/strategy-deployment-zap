// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {IStrategyDeploymentZap} from "src/interfaces/IStrategyDeploymentZap.sol";

import {StrategyDeploymentZap_Unit_Concrete_Test} from "../strategy-deployment-zap/StrategyDeploymentZap.t.sol";
import {
    ScheduleDeployment_Unit_Concrete_Test
} from "../strategy-deployment-zap/schedule-deployment/scheduleDeployment.t.sol";
import {CancelDeployment_Unit_Concrete_Test} from "../strategy-deployment-zap/cancel-deployment/cancelDeployment.t.sol";
import {Base_Hub_Test, Base_Test} from "../../../base/Base.t.sol";

abstract contract HubStrategyDeploymentZap_Unit_Concrete_Test is
    StrategyDeploymentZap_Unit_Concrete_Test,
    Base_Hub_Test
{
    function setUp() public virtual override(Base_Hub_Test, Base_Test) {
        Base_Hub_Test.setUp();

        strategyDeploymentZap = IStrategyDeploymentZap(address(hubStrategyDeploymentZap));
    }
}

contract Getters_HubStrategyDeploymentZap_Unit_Concrete_Test is HubStrategyDeploymentZap_Unit_Concrete_Test {
    function test_Getters() public view {
        assertEq(hubStrategyDeploymentZap.hubCoreFactory(), address(hubCoreFactory));
        assertEq(hubStrategyDeploymentZap.hubPeripheryFactory(), address(hubPeripheryFactory));
        assertEq(hubStrategyDeploymentZap.scheduledDeploymentTimepoint(address(0), 0), 0);
    }
}

contract ScheduleDeployment_HubStrategyDeploymentZap_Unit_Concrete_Test is
    HubStrategyDeploymentZap_Unit_Concrete_Test,
    ScheduleDeployment_Unit_Concrete_Test
{
    function setUp()
        public
        virtual
        override(HubStrategyDeploymentZap_Unit_Concrete_Test, ScheduleDeployment_Unit_Concrete_Test)
    {
        HubStrategyDeploymentZap_Unit_Concrete_Test.setUp();
        ScheduleDeployment_Unit_Concrete_Test.setUp();
    }
}

contract CancelDeployment_HubStrategyDeploymentZap_Unit_Concrete_Test is
    HubStrategyDeploymentZap_Unit_Concrete_Test,
    CancelDeployment_Unit_Concrete_Test
{
    function setUp()
        public
        virtual
        override(HubStrategyDeploymentZap_Unit_Concrete_Test, CancelDeployment_Unit_Concrete_Test)
    {
        HubStrategyDeploymentZap_Unit_Concrete_Test.setUp();
        CancelDeployment_Unit_Concrete_Test.setUp();
    }
}
