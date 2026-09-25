# Deploy Makina Strategy Deployment Zap

This README outlines the steps to deploy the `HubStrategyDeploymentZap` contract and to create Machine instances through it.

## Environment setup

- Copy `.env.example` to `.env` and fill in the required RPC URLs and the Etherscan API key.
- Mainnet is preconfigured in `foundry.toml` and only requires the corresponding environment variable. More networks can be added following similar configuration.
- Notation used in the commands:
  - `<wallet-options>` - the flags specifying the deployer wallet, e.g. `--account <keystore-name>` for a Foundry keystore. For other options, refer to the [Foundry docs](https://getfoundry.sh/forge/reference/script/)
  - `<network-alias>` - must match a network name declared in `foundry.toml`
- Each script documents its env vars in its NatSpec header.

## Zap Contract Deployment

Set the `ZAP_INPUT_FILENAME` and `ZAP_OUTPUT_FILENAME` values in your `.env` file to define the input and output JSON filenames, respectively. For example, for a deployment on Ethereum Mainnet, both of these files can be named `Mainnet.json`.

1. Copy `script/deploy/inputs/hub-strategy-deployment-zaps/TEMPLATE.json` to `script/deploy/inputs/hub-strategy-deployment-zaps/{ZAP_INPUT_FILENAME}` and fill in the required variables (`initialOwner`, `hubCoreFactory`, `hubPeripheryFactory`).
2. Run the following command to initiate the deployment. This will generate an output file at `script/deploy/outputs/hub-strategy-deployment-zaps/{ZAP_OUTPUT_FILENAME}` containing the deployed contract address.

```shell
forge script script/deploy/DeployHubStrategyDeploymentZap.s.sol --rpc-url <network-alias> <wallet-options> --slow --broadcast --verify -vvvv
```

Note: This script performs deterministic deployment based on the deployer wallet address via the [CreateX Factory contract](https://github.com/pcaversaccio/createx).

The `initialOwner` set here is the address allowed to schedule and cancel deployments on the zap.

The zap calls the core and periphery factories on its own behalf, so the **deployed zap address** must be granted the `STRATEGY_DEPLOYMENT_ROLE` in the Makina Core `AccessManager` for the deployments to succeed. Once the zap address is known, an `AccessManager` admin submits:

```solidity
accessManager.grantRole(STRATEGY_DEPLOYMENT_ROLE, <deployed-zap-address>, 0)
```

## Machine Creation

Creating a Machine through the zap is a two-phase, timelocked operation:

1. The zap owner schedules the deployment payload, providing the address allowed to execute it (`executor`) and a `delay`.
2. Once the delay has elapsed, the `executor` executes the deployment.

The schedule and execute scripts of a given variant read the **same** input file so that the encoded payload, and therefore its hash, is identical across both phases. Do not modify the input file between scheduling and executing.

Set the `ZAP_OUTPUT_FILENAME` (from the zap deployment step), `HUB_STRAT_INPUT_FILENAME` and `HUB_STRAT_OUTPUT_FILENAME` values in your `.env` file.

### View mode

Set `VIEW_MODE=true` in your `.env` to run any of the schedule/execute scripts below without broadcasting: each one logs the target address and the calldata it would send, then exits without sending a transaction or writing an output file. `HUB_STRAT_OUTPUT_FILENAME` is not needed in this mode. This is useful to review a payload or to submit it from a multisig. Leave the variable unset (or `false`) for normal broadcasting.

### Periphery module initialization data

The `peripheryParams` field of a machine input file holds the ABI-encoded initialization data for the machine's periphery modules (depositor, redeemer, fee manager). Instead of encoding these blobs and pasting them in by hand, they are generated from human-readable, per-module config files.

There is one folder per machine periphery slot, each containing a `TEMPLATE.json`:

- `script/deploy/inputs/machine-depositors/`
- `script/deploy/inputs/machine-redeemers/`
- `script/deploy/inputs/machine-fee-managers/`

Each config file declares its own `implemId` alongside the fields required by that implementation. The encoder selects how to parse and encode the file based on this `implemId`, so a single folder covers every implementation of a slot (for example, both `AsyncRedeemer` and `AsyncRedeemerFee` live in `machine-redeemers/`).

Copy the relevant `TEMPLATE.json` files, fill them in, and set the following values in your `.env` file (leave a slot's variable unset to skip that module):

- `DEPOSITOR_INPUT_FILENAME` - file in `machine-depositors/`
- `REDEEMER_INPUT_FILENAME` - file in `machine-redeemers/`
- `FEE_MANAGER_INPUT_FILENAME` - file in `machine-fee-managers/`
- `HUB_STRAT_INPUT_SUBDIR` - `create-machines` (default) or `create-machines-from-pre-deposit`
- `HUB_STRAT_INPUT_FILENAME` - the machine input file whose `peripheryParams` will be written

Then run the following command to generate the init data:

```shell
forge script script/deploy/EncodePeripheryInitData.s.sol
```

This writes the `peripheryParams` (implementation IDs and encoded init data) into `script/deploy/inputs/{HUB_STRAT_INPUT_SUBDIR}/{HUB_STRAT_INPUT_FILENAME}`, leaving all other fields untouched. It only generates a local file and does not broadcast any transaction. To change the periphery setup, edit the per-module config files and re-run this script rather than hand-editing `peripheryParams`. Run this step before scheduling, and do not modify the input file between scheduling and executing.

### Plain Machine instance

1. Copy `script/deploy/inputs/create-machines/TEMPLATE.json` to `script/deploy/inputs/create-machines/{HUB_STRAT_INPUT_FILENAME}` and fill in the required variables, except `peripheryParams`. Set `executor` to the address that will execute the deployment, and `delay` to the timelock delay in seconds. Then generate `peripheryParams` as described in [Periphery module initialization data](#periphery-module-initialization-data), with `HUB_STRAT_INPUT_SUBDIR=create-machines`.
2. Run the following command from the zap owner to schedule the deployment.

```shell
forge script script/deploy/ScheduleCreateMachine.s.sol --rpc-url <network-alias> <wallet-options> --slow --broadcast -vvvv
```

3. Once the delay has elapsed, run the following command from the `executor` address to execute the deployment. This will generate an output file at `script/deploy/outputs/create-machines/{HUB_STRAT_OUTPUT_FILENAME}` containing the deployed Machine and Caliber addresses.

```shell
forge script script/deploy/CreateMachine.s.sol --rpc-url <network-alias> <wallet-options> --slow --broadcast -vvvv
```

### Machine instance from a Pre-Deposit Vault

1. Copy `script/deploy/inputs/create-machines-from-pre-deposit/TEMPLATE.json` to `script/deploy/inputs/create-machines-from-pre-deposit/{HUB_STRAT_INPUT_FILENAME}` and fill in the required variables, including the `preDepositVault` address to migrate, except `peripheryParams`. Then generate `peripheryParams` as described in [Periphery module initialization data](#periphery-module-initialization-data), with `HUB_STRAT_INPUT_SUBDIR=create-machines-from-pre-deposit`.
2. Run the following command from the zap owner to schedule the deployment.

```shell
forge script script/deploy/ScheduleCreateMachineFromPreDeposit.s.sol --rpc-url <network-alias> <wallet-options> --slow --broadcast -vvvv
```

3. Once the delay has elapsed, run the following command from the `executor` address to execute the deployment. This will generate an output file at `script/deploy/outputs/create-machines-from-pre-deposit/{HUB_STRAT_OUTPUT_FILENAME}`.

```shell
forge script script/deploy/CreateMachineFromPreDeposit.s.sol --rpc-url <network-alias> <wallet-options> --slow --broadcast -vvvv
```

## Spoke Caliber

The zap only deploys the hub side of a strategy. Extending a Machine to a spoke chain is done outside of this repository, using the `DeploySpokeCaliber.s.sol` script of the [makina-core](https://github.com/MakinaHQ/makina-core/blob/main/script/deploy/DeploySpokeCaliber.s.sol) repository, which calls [`SpokeCoreFactory.createCaliber`](https://docs.makina.finance/contracts/core/factories/SpokeCoreFactory.sol/contract.SpokeCoreFactory#createcaliber).

Once the Caliber is deployed, link it to the Machine:

1. Call [`Machine.setSpokeCaliber`](https://docs.makina.finance/contracts/core/interfaces/IMachine.sol/interface.IMachine#setspokecaliber) on the hub chain, providing the spoke chain ID, the deployed Caliber mailbox address, and the supported bridges with their spoke adapters.
2. Call [`CaliberMailbox.setHubBridgeAdapter`](https://docs.makina.finance/contracts/core/caliber/CaliberMailbox.sol/contract.CaliberMailbox#sethubbridgeadapter) on the spoke chain, for each bridge, to register the corresponding hub bridge adapter.
