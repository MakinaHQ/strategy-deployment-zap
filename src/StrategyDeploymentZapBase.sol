// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {IStrategyDeploymentZap} from "./interfaces/IStrategyDeploymentZap.sol";

contract StrategyDeploymentZapBase is IStrategyDeploymentZap, Ownable {
    /// @dev Timepoint used to mark executed deployments in the `scheduledDeployments` mapping.
    uint256 private constant EXECUTED_TIMEPOINT = type(uint256).max;

    mapping(address executor => mapping(bytes32 payloadHash => uint256 timepoint)) private scheduledDeployments;

    constructor(address _initialOwner) Ownable(_initialOwner) {}

    /// @inheritdoc IStrategyDeploymentZap
    function scheduledDeploymentTimepoint(address executor, bytes32 payloadHash) external view returns (uint256) {
        return scheduledDeployments[executor][payloadHash];
    }

    /// @inheritdoc IStrategyDeploymentZap
    function scheduleDeployment(address executor, bytes calldata payload, uint256 delay) external onlyOwner {
        bytes32 payloadHash = keccak256(payload);
        if (scheduledDeployments[executor][payloadHash] == EXECUTED_TIMEPOINT) {
            revert DeploymentAlreadyExecuted();
        }
        if (scheduledDeployments[executor][payloadHash] != 0) {
            revert DeploymentAlreadyScheduled();
        }

        uint256 timepoint = block.timestamp + delay;
        if (timepoint == EXECUTED_TIMEPOINT) {
            revert InvalidDelay();
        }

        scheduledDeployments[executor][payloadHash] = timepoint;
        emit DeploymentScheduled(executor, payloadHash, timepoint);
    }

    /// @inheritdoc IStrategyDeploymentZap
    function cancelDeployment(address executor, bytes32 payloadHash) external onlyOwner {
        if (scheduledDeployments[executor][payloadHash] == 0) {
            revert DeploymentNotScheduled();
        }
        if (scheduledDeployments[executor][payloadHash] == EXECUTED_TIMEPOINT) {
            revert DeploymentAlreadyExecuted();
        }

        delete scheduledDeployments[executor][payloadHash];
        emit DeploymentCanceled(executor, payloadHash);
    }

    /// @dev Checks that the deployment identified by the executor and payload hash is ready to be executed, and marks it as executed.
    function _consumeSchedule(address executor, bytes32 payloadHash) internal {
        if (scheduledDeployments[executor][payloadHash] == 0) {
            revert DeploymentNotScheduled();
        }
        if (block.timestamp < scheduledDeployments[executor][payloadHash]) {
            revert DeploymentNotReady();
        }
        scheduledDeployments[executor][payloadHash] = EXECUTED_TIMEPOINT;
    }
}
