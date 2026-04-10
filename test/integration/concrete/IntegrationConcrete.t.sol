// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {MockERC20} from "@makina-core-test/mocks/MockERC20.sol";
import {MockPriceFeed} from "@makina-core-test/mocks/MockPriceFeed.sol";

import {Base_Test, Base_Hub_Test} from "../../base/Base.t.sol";

abstract contract Integration_Concrete_Test is Base_Test {
    address internal accountingAgent;

    uint256 internal scheduleDelay;

    MockERC20 public accountingToken;
    MockERC20 public baseToken;

    MockPriceFeed internal aPriceFeed1;
    MockPriceFeed internal bPriceFeed1;

    function setUp() public virtual override {
        Base_Test.setUp();

        accountingAgent = makeAddr("accountingAgent");

        scheduleDelay = 1 hours;

        accountingToken = new MockERC20("accountingToken", "ACT", 18);
        baseToken = new MockERC20("baseToken", "BT", 18);

        aPriceFeed1 = new MockPriceFeed(18, 1e18, block.timestamp);
        bPriceFeed1 = new MockPriceFeed(18, 1e18, block.timestamp);

        vm.startPrank(dao);
        oracleRegistry.setFeedRoute(
            address(accountingToken), address(aPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0
        );
        oracleRegistry.setFeedRoute(address(baseToken), address(bPriceFeed1), DEFAULT_PF_STALE_THRSHLD, address(0), 0);
        vm.stopPrank();
    }
}

abstract contract Integration_Concrete_Hub_Test is Integration_Concrete_Test, Base_Hub_Test {
    function setUp() public virtual override(Integration_Concrete_Test, Base_Hub_Test) {
        Base_Hub_Test.setUp();
        Integration_Concrete_Test.setUp();
    }
}
