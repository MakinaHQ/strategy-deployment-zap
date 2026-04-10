# Makina Access Control

## Roles Permissions List

### StrategyDeploymentZapBase

- **Owner**
  - Can schedule a deployment for a given executor and payload, with a specified delay.
  - Can cancel a scheduled deployment that has not yet been executed.
  - Can transfer ownership.
  - Can renounce ownership.

### HubStrategyDeploymentZap

- **Scheduled Executor**
  - Can execute `createMachine` after the scheduled timepoint has been reached.
  - Can execute `createMachineFromPreDeposit` after the scheduled timepoint has been reached.
