# Makina Deployment Zap Contracts

This repository contains a zap contract to facilitate deployment of Makina strategies. The zap contract orchestrates the creation and setup of a Hub strategy instance (Machine + periphery modules + Caliber) in a single scheduled transaction, using a timelock mechanism for deployment governance.

See `SPECIFICATIONS.md` and `PERMISSIONS.md` for more details.

## Contracts Overview

| Filename                       | Deployment chain | Description                                                                                        |
| ------------------------------ | ---------------- | -------------------------------------------------------------------------------------------------- |
| `HubStrategyDeploymentZap.sol` | Hub              | Orchestrates deployment of a Machine and its periphery modules (depositor, redeemer, fee manager). |

## Installation

Follow [this link](https://book.getfoundry.sh/getting-started/installation) to install the Foundry toolchain.

Run below commands to install and use Foundry:

```shell
foundryup
```

## Submodules

Run below command to include/update all git submodules like forge-std, openzeppelin contracts etc (`lib/`)

```shell
git submodule update --init --recursive
```

## Dependencies

Run below command to include project dependencies like prettier and solhint (`node_modules/`)

```shell
yarn
```

### Build

Run below command to compile all other contracts

```shell
forge build
```

### Test

```shell
forge test
```

### Coverage

```shell
yarn coverage
```

### Format

```shell
forge fmt
```

### Lint

```shell
yarn lint
```
