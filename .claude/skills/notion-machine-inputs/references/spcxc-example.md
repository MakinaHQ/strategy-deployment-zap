# Worked example: Dialectic Yielding SPCXc (Base)

Deployed 2026-09-03 through the zap at `0xb83315E639ffC5596b53F215FCFE43d28Cf1842F` on Base. Machine
`0x47b574313Bf529098e1e55F397bC9D160ba3089c`, hub caliber `0x57A25af7F054Cd8C4f7899f4cbbE4A0D455A57A2`. All values
below were read from the live contracts on 2026-09-23 and match the deployment.

## Machines row

| Column                  | Value                                                                                                 |
| ----------------------- | ----------------------------------------------------------------------------------------------------- |
| Name                    | SPCXc                                                                                                 |
| Accounting token (Base) | `0xb2000000000000000000007b9fcbd005511aCBd5`                                                          |
| Share token name        | Dialectic Yielding SPCXc                                                                              |
| Share token symbol      | ySPCXc                                                                                                |
| Salt                    | `0xac710a276bc6823441876ba13196dcbc6c023cbb2773dc800b4e51a148b6725f`                                  |
| Oracle feed 1           | Chainlink "Coinbase SPCX" `0x6A634B235903C4ad6376892180d6fF8612e3Fa68`, 8 decimals, 87000 s staleness |

## Shared Parameters rows

| Key                                                        | Value                                                                                  |
| ---------------------------------------------------------- | -------------------------------------------------------------------------------------- |
| zap.executor                                               | 0x36BA7c92Cd68051fB304Bd4580C4A51c1d376532                                             |
| zap.delay                                                  | 0                                                                                      |
| setupAMFunctionRoles                                       | true                                                                                   |
| bridgeAdapterInitParams                                    | []                                                                                     |
| spokeSnapshotConsumerInitParams.initialCreWorkflowIds      | []                                                                                     |
| depositor.implemId                                         | 1001                                                                                   |
| depositor.whitelist                                        | false                                                                                  |
| depositor.sanctionsCheck                                   | true                                                                                   |
| redeemer.implemId                                          | 2001                                                                                   |
| redeemer.finalizationDelay                                 | 259200                                                                                 |
| redeemer.minRedeemAmount                                   | 10000000000000000                                                                      |
| redeemer.whitelist                                         | false                                                                                  |
| redeemer.sanctionsCheck                                    | true                                                                                   |
| feeManager.implemId                                        | 3001                                                                                   |
| feeManager.mgmtFeeRatePerSecond                            | 158548959                                                                              |
| feeManager.smFeeRatePerSecond                              | 0                                                                                      |
| feeManager.perfFeeRate                                     | 150000000000000000                                                                     |
| feeManager.mgmtFeeReceivers                                | 0x7D51ADf77332c5BbD33f91de00646ebA099C0D2F, 0x68825BAfF4CaEDf6fAcc658269Cf1a0491F1Ba9f |
| feeManager.mgmtFeeSplitBps                                 | 7000, 3000                                                                             |
| feeManager.perfFeeReceivers                                | 0x7D51ADf77332c5BbD33f91de00646ebA099C0D2F, 0x68825BAfF4CaEDf6fAcc658269Cf1a0491F1Ba9f |
| feeManager.perfFeeSplitBps                                 | 7000, 3000                                                                             |
| machineInitParams.initialCaliberStaleThreshold             | 172800                                                                                 |
| machineInitParams.initialMaxFixedFeeAccrualRate            | 475646879                                                                              |
| machineInitParams.initialMaxPerfFeeAccrualRate             | 14269406392                                                                            |
| machineInitParams.initialFeeMintCooldown                   | 86400                                                                                  |
| machineInitParams.initialShareLimit                        | 115792089237316195423570985008687907853269984665640564039457584007913129639935         |
| machineInitParams.initialMaxSharePriceChangeRate           | 31709791983                                                                            |
| caliberInitParams.initialPositionStaleThreshold            | 172800                                                                                 |
| caliberInitParams.initialAllowedInstrRoot                  | 0x0000000000000000000000000000000000000000000000000000000000000000                     |
| caliberInitParams.initialTimelockDuration                  | 3600                                                                                   |
| caliberInitParams.initialMaxPositionIncreaseLossBps        | 50                                                                                     |
| caliberInitParams.initialMaxPositionDecreaseLossBps        | 50                                                                                     |
| caliberInitParams.initialMaxSwapLossBps                    | 100                                                                                    |
| caliberInitParams.initialCooldownDuration                  | 12                                                                                     |
| caliberInitParams.initialBaseTokens                        | 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913                                             |
| makinaGovernableInitParams.initialMechanic                 | 0x425BbC2cfF0c7E7960baA9BaC2f0Cb67B41d3beF                                             |
| makinaGovernableInitParams.initialSecurityCouncil          | 0x89faa3b02EF5aB185b8ACE489Af62748ACB50Afc                                             |
| makinaGovernableInitParams.initialRiskManager              | 0x36BA7c92Cd68051fB304Bd4580C4A51c1d376532                                             |
| makinaGovernableInitParams.initialRiskManagerTimelock      | 0x36BA7c92Cd68051fB304Bd4580C4A51c1d376532                                             |
| makinaGovernableInitParams.initialAuthority                | 0x0fCEfa3f1047F35521A49cD8B06faBd588665d7F                                             |
| makinaGovernableInitParams.initialRestrictedAccountingMode | true                                                                                   |
| makinaGovernableInitParams.initialAccountingAgents         | 0xf415F3DEA67654bA2B7dc2344733e52Abb7A6095                                             |

## Resulting files (before encode; the encoder later fills and reorders only the `peripheryParams` block)

`script/deployments/inputs/create-machines/Base-SPCXc.json`

```json
{
  "executor": "0x36BA7c92Cd68051fB304Bd4580C4A51c1d376532",
  "delay": 0,
  "peripheryParams": {
    "depositorImplemId": 0,
    "redeemerImplemId": 0,
    "feeManagerImplemId": 0,
    "depositorInitData": "0x",
    "redeemerInitData": "0x",
    "feeManagerInitData": "0x"
  },
  "machineInitParams": {
    "initialDepositor": "0x0000000000000000000000000000000000000000",
    "initialRedeemer": "0x0000000000000000000000000000000000000000",
    "initialFeeManager": "0x0000000000000000000000000000000000000000",
    "initialCaliberStaleThreshold": 172800,
    "initialMaxFixedFeeAccrualRate": 475646879,
    "initialMaxPerfFeeAccrualRate": 14269406392,
    "initialFeeMintCooldown": 86400,
    "initialShareLimit": "115792089237316195423570985008687907853269984665640564039457584007913129639935",
    "initialMaxSharePriceChangeRate": 31709791983
  },
  "caliberInitParams": {
    "initialPositionStaleThreshold": 172800,
    "initialAllowedInstrRoot": "0x0000000000000000000000000000000000000000000000000000000000000000",
    "initialTimelockDuration": 3600,
    "initialMaxPositionIncreaseLossBps": 50,
    "initialMaxPositionDecreaseLossBps": 50,
    "initialMaxSwapLossBps": 100,
    "initialCooldownDuration": 12,
    "initialBaseTokens": ["0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913"]
  },
  "makinaGovernableInitParams": {
    "initialMechanic": "0x425BbC2cfF0c7E7960baA9BaC2f0Cb67B41d3beF",
    "initialSecurityCouncil": "0x89faa3b02EF5aB185b8ACE489Af62748ACB50Afc",
    "initialRiskManager": "0x36BA7c92Cd68051fB304Bd4580C4A51c1d376532",
    "initialRiskManagerTimelock": "0x36BA7c92Cd68051fB304Bd4580C4A51c1d376532",
    "initialAuthority": "0x0fCEfa3f1047F35521A49cD8B06faBd588665d7F",
    "initialRestrictedAccountingMode": true,
    "initialAccountingAgents": ["0xf415F3DEA67654bA2B7dc2344733e52Abb7A6095"]
  },
  "spokeSnapshotConsumerInitParams": {
    "initialCreWorkflowIds": []
  },
  "bridgeAdapterInitParams": [],
  "accountingToken": "0xb2000000000000000000007b9fcbd005511aCBd5",
  "shareTokenName": "Dialectic Yielding SPCXc",
  "shareTokenSymbol": "ySPCXc",
  "salt": "0xac710a276bc6823441876ba13196dcbc6c023cbb2773dc800b4e51a148b6725f",
  "setupAMFunctionRoles": true
}
```

`script/deployments/inputs/machine-depositors/Base-SPCXc.json`

```json
{
  "implemId": 1001,
  "whitelist": false,
  "sanctionsCheck": true
}
```

`script/deployments/inputs/machine-redeemers/Base-SPCXc.json`

```json
{
  "implemId": 2001,
  "finalizationDelay": 259200,
  "minRedeemAmount": "10000000000000000",
  "whitelist": false,
  "sanctionsCheck": true
}
```

`script/deployments/inputs/machine-fee-managers/Base-SPCXc.json`

```json
{
  "implemId": 3001,
  "mgmtFeeRatePerSecond": 158548959,
  "smFeeRatePerSecond": 0,
  "perfFeeRate": "150000000000000000",
  "mgmtFeeReceivers": [
    "0x7D51ADf77332c5BbD33f91de00646ebA099C0D2F",
    "0x68825BAfF4CaEDf6fAcc658269Cf1a0491F1Ba9f"
  ],
  "mgmtFeeSplitBps": [7000, 3000],
  "perfFeeReceivers": [
    "0x7D51ADf77332c5BbD33f91de00646ebA099C0D2F",
    "0x68825BAfF4CaEDf6fAcc658269Cf1a0491F1Ba9f"
  ],
  "perfFeeSplitBps": [7000, 3000]
}
```

## Regression check

With the four files above and the env vars from the skill (names `Base-SPCXc.json`), run the encoder and then
`VIEW_ONLY=true forge script script/deployments/ScheduleCreateMachine.s.sol`. No RPC or keys are needed. The printed
calldata equals the `Zap scheduleDeployment tx` block on the SPCXc Notion checklist; the self-contained check is its
sha256 (the hex string after `calldata:`, `0x` prefix kept, no whitespace or trailing newline):

```
786f9f3343b5c01ceba7f828a61410ea0d586b07e3ee03d06349a596562468dd
```

Delete the `Base-SPCXc.json` files afterwards; SPCXc is already deployed.
