# Strategy Deployment Zap Specifications

## StrategyDeploymentZapBase

The `StrategyDeploymentZapBase` contract provides a timelock-based scheduling mechanism for strategy deployments. It ensures that deployments are pre-approved and time-gated before execution.

### Deployment Scheduling

The contract owner can schedule deployments by registering the hash of the deployment payload alongside a delay. The deployment can only be executed after the specified delay has elapsed. Each deployment is uniquely identified by the combination of an executor address and a payload hash, and can only be executed once. Once consumed, the schedule is permanently marked as executed.

### Deployment Cancellation

The contract owner can cancel any scheduled deployment that has not yet been executed. Cancelled deployments are removed from the schedule and cannot be executed.

## HubStrategyDeploymentZap

The `HubStrategyDeploymentZap` contract orchestrates the deployment and configuration of a Makina Hub strategy instance in a single transaction. It interacts with both the `HubCoreFactory` and the `HubPeripheryFactory` to deploy all required components and link them together.

### Machine Deployment

The `createMachine` function deploys a new `Machine` instance along with its periphery modules (depositor, redeemer, fee manager). It first creates each periphery module through the `HubPeripheryFactory`, then deploys the machine through the `HubCoreFactory`, and finally links the periphery modules to the deployed machine.

### Machine Deployment from Pre-Deposit Vault

The `createMachineFromPreDeposit` function follows the same flow as `createMachine`, but deploys the machine by migrating an existing `PreDepositVault` instance instead of creating a fresh machine. The deposited assets and share token ownership are transferred from the vault to the newly deployed machine.

### Periphery Module Handling

For each machine periphery module, creation is conditional on a non-zero implementation ID being provided. When an implementation ID is set, the corresponding module is deployed through the `HubPeripheryFactory` and its address is injected into the `MachineInitParams` before machine deployment. `MachineInitParams` cannot contain a non-zero address and a non-zero implementation ID for the same module.

After machine deployment, all factory-created periphery modules are linked to the deployed machine via the `HubPeripheryFactory`.

## Access Control

The `HubStrategyDeploymentZap` contract uses [OpenZeppelin Ownable](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol) for access control. See [PERMISSIONS.md](PERMISSIONS.md) for the full list of permissions.

In order to execute deployments via `HubCoreFactory` and `HubPeripheryFactory`, `HubStrategyDeploymentZap` needs to be granted `STRATEGY_DEPLOYMENT_ROLE` (roleId `2`) in Makina core's access manager.
