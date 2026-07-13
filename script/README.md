# Deploy Makina Strategy Deployment Zap

This README outlines the steps to deploy the `HubStrategyDeploymentZap` contract and to create Machine instances through it.

## Environment setup

- Copy `.env.example` to `.env` and fill in the required RPC URLs, Etherscan API URLs, and API keys.
- Some networks are preconfigured in `foundry.toml` and only require the corresponding environment variables. More networks can be added following similar configuration.
- The commands below use a foundry keystore to specify the deployment wallet (`--account <keystore-name>`). For other options, refer to the [Foundry docs](https://getfoundry.sh/forge/reference/script/).
- Notation used in the commands:
  - `<keystore-name>` - the name of a Foundry keystore containing the deployer's private key
  - `<network-alias>` - must match a network name declared in `foundry.toml`

## Zap Contract Deployment

Set the `ZAP_INPUT_FILENAME` and `ZAP_OUTPUT_FILENAME` values in your `.env` file to define the input and output JSON filenames, respectively. For example, for a deployment on Ethereum Mainnet, both of these files can be named `Mainnet.json`.

1. Copy `script/deployments/inputs/hub-strategy-deployment-zaps/TEMPLATE.json` to `script/deployments/inputs/hub-strategy-deployment-zaps/{ZAP_INPUT_FILENAME}` and fill in the required variables (`initialOwner`, `hubCoreFactory`, `hubPeripheryFactory`).
2. Run the following command to initiate the deployment. This will generate an output file at `script/deployments/outputs/hub-strategy-deployment-zaps/{ZAP_OUTPUT_FILENAME}` containing the deployed contract address.

```
forge script script/deployments/DeployHubStrategyDeploymentZap.s.sol --rpc-url <network-alias> --account <keystore-name> --slow --broadcast --verify -vvvv
```

The `initialOwner` set here is the address allowed to schedule and cancel deployments on the zap. It must also be granted the `STRATEGY_DEPLOYMENT_ROLE` in the Makina Core `AccessManager` for the deployments to succeed.

## Machine Creation

Creating a Machine through the zap is a two-phase, timelocked operation:

1. The zap owner schedules the deployment payload, providing the address allowed to execute it (`executor`) and a `delay`.
2. Once the delay has elapsed, the `executor` executes the deployment.

The schedule and execute scripts of a given variant read the **same** input file so that the encoded payload, and therefore its hash, is identical across both phases. Do not modify the input file between scheduling and executing.

Set the `ZAP_OUTPUT_FILENAME` (from the zap deployment step), `HUB_STRAT_INPUT_FILENAME` and `HUB_STRAT_OUTPUT_FILENAME` values in your `.env` file.

### Plain Machine instance

1. Copy `script/deployments/inputs/create-machines/TEMPLATE.json` to `script/deployments/inputs/create-machines/{HUB_STRAT_INPUT_FILENAME}` and fill in the required variables. Set `executor` to the address that will execute the deployment, and `delay` to the timelock delay in seconds.
2. Run the following command from the zap owner to schedule the deployment.

```
forge script script/deployments/ScheduleCreateMachine.s.sol --rpc-url <network-alias> --account <keystore-name> --slow --broadcast -vvvv
```

3. Once the delay has elapsed, run the following command from the `executor` address to execute the deployment. This will generate an output file at `script/deployments/outputs/create-machines/{HUB_STRAT_OUTPUT_FILENAME}` containing the deployed Machine and Caliber addresses.

```
forge script script/deployments/CreateMachine.s.sol --rpc-url <network-alias> --account <keystore-name> --slow --broadcast -vvvv
```

### Machine instance from a Pre-Deposit Vault

1. Copy `script/deployments/inputs/create-machines-from-pre-deposit/TEMPLATE.json` to `script/deployments/inputs/create-machines-from-pre-deposit/{HUB_STRAT_INPUT_FILENAME}` and fill in the required variables, including the `preDepositVault` address to migrate.
2. Run the following command from the zap owner to schedule the deployment.

```
forge script script/deployments/ScheduleCreateMachineFromPreDeposit.s.sol --rpc-url <network-alias> --account <keystore-name> --slow --broadcast -vvvv
```

3. Once the delay has elapsed, run the following command from the `executor` address to execute the deployment. This will generate an output file at `script/deployments/outputs/create-machines-from-pre-deposit/{HUB_STRAT_OUTPUT_FILENAME}`.

```
forge script script/deployments/CreateMachineFromPreDeposit.s.sol --rpc-url <network-alias> --account <keystore-name> --slow --broadcast -vvvv
```
