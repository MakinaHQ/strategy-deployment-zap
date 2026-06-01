// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface IStrategyDeploymentZap {
    error DeploymentNotReady();
    error DeploymentNotScheduled();
    error DeploymentAlreadyExecuted();
    error DeploymentAlreadyScheduled();
    error InvalidDelay();

    event DeploymentCanceled(address indexed executor, bytes32 indexed payloadHash);
    event DeploymentExecuted(address indexed executor, bytes32 indexed payloadHash);
    event DeploymentScheduled(address indexed executor, bytes32 indexed payloadHash, uint256 timepoint);

    /// @dev Returns the scheduled timepoint for the deployment identified by the executor and payload hash,
    ///      0 if not scheduled, and `type(uint256).max` if already executed.
    /// @param executor The address of the executor of the deployment.
    /// @param payloadHash The hash of the deployment payload.
    /// @return The scheduled timepoint for the deployment.
    function scheduledDeploymentTimepoint(address executor, bytes32 payloadHash) external view returns (uint256);

    /// @notice Schedules a strategy deployment to be executed after a specified delay.
    /// @param executor The address of the executor of the deployment.
    /// @param payload The encoded deployment payload.
    /// @param delay The delay in seconds after which the deployment can be executed.
    function scheduleDeployment(address executor, bytes calldata payload, uint256 delay) external;

    /// @notice Cancels a scheduled strategy deployment.
    /// @param executor The address of the executor of the deployment.
    /// @param payloadHash The hash of the deployment payload.
    function cancelDeployment(address executor, bytes32 payloadHash) external;
}
