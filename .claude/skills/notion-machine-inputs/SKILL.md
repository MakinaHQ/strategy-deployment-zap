---
name: notion-machine-inputs
description: Turn a Makina machine deployment checklist in Notion (a per-machine table plus a shared-parameters table) into the input JSON files under script/deployments/inputs that this repo's EncodePeripheryInitData, ScheduleCreateMachine and CreateMachine scripts consume, then drive those scripts per machine and write the results back to Notion. Use this whenever someone asks to prepare, export, generate, refresh or check machine deployment inputs from Notion, to deploy the Dialectic Yielding Stocks machines (AAPLc, TSLAc, ...) or any checklist-driven batch of machines, or mentions the Machines / Shared Parameters tables, the Inputs confirmed or Confirmed ticks, Base-<Ticker>.json files, or "the checklist page".
---

# Notion checklist to machine inputs

The deployment checklist in Notion is the sign-off record for a machine launch. Two tables on the checklist page hold
everything the zap needs: a **Machines** table (one row per machine, the values that differ between machines) and a
**Shared Parameters** table (one row per JSON field common to all machines, keyed by the dotted path it lands in). This
skill turns those rows into the four input files the deployment scripts read, without anyone hand-encoding anything.

Current checklist: "Dialectic Yielding Stocks (7 machines) Checklist"
https://app.notion.com/p/3e4ed517186a8187a65bdfaaa84268b9

- Machines data source: `collection://434a63fd-cb87-4ef8-8b57-707a6fd797ed`
- Shared Parameters data source: `collection://2aa96b7f-8a71-467d-89d3-6ee3dd316606`

If the user points at a different checklist, fetch that page and take the two `collection://` ids from its
`<database ... data-source-url>` tags instead.

## 1. Read the tables

Use the Notion tools (`notion-query-data-sources` in **rows** mode, or `notion-fetch` on the collection URL). Rows mode
keeps addresses and long numbers intact; SQL mode can drop rich-text formatting, which does not matter for plain
values but rows mode is the safer default. Pull both tables completely before writing anything.

## 2. Respect the gates

Export a machine only when its **Inputs confirmed** box is ticked, and only when every Shared Parameters row has
**Confirmed** ticked. These ticks are the review trail: the same input file is hashed at schedule time and at execute
time, so a value that slips in unreviewed ends up on-chain. If the user asks for a dry run or a preview, produce the
files but say clearly which gates are not met. Do not silently skip the check.

Also refuse (and say why) when a shared row a file needs is missing or empty, when a fee split does not sum to 10000
or its receivers list has a different length, when an address is not 40 hex characters, or when two machines share a
salt or a share token symbol.

## 3. Write the four files per machine

File name: `Base-<Name>.json` where `<Name>` is the Machines row title (for example `Base-AAPLc.json`). Use the same
name in all four folders so one set of env vars covers a machine.

| File                                                         | Contents                                                                    |
| ------------------------------------------------------------ | --------------------------------------------------------------------------- |
| `script/deployments/inputs/create-machines/Base-T.json`      | Machine, caliber, governance params, token, salt (shape of `TEMPLATE.json`) |
| `script/deployments/inputs/machine-depositors/Base-T.json`   | `depositor.*` shared rows                                                   |
| `script/deployments/inputs/machine-redeemers/Base-T.json`    | `redeemer.*` shared rows                                                    |
| `script/deployments/inputs/machine-fee-managers/Base-T.json` | `feeManager.*` shared rows                                                  |

Mapping rules, and the reasons behind them:

- **Shared `Key` is the JSON path.** `machineInitParams.initialShareLimit` goes to `machineInitParams.initialShareLimit`
  in the create-machines file; `depositor.whitelist` goes to `whitelist` in the depositor file; `zap.executor` and
  `zap.delay` are the top-level `executor` and `delay`; `setupAMFunctionRoles`, `bridgeAdapterInitParams` and
  `spokeSnapshotConsumerInitParams.initialCreWorkflowIds` are top-level as named.
- **From the Machines row:** `accountingToken` (column "Accounting token (Base)"), `shareTokenName`,
  `shareTokenSymbol`, `salt`.
- **Fixed by the zap flow:** `machineInitParams.initialDepositor`, `initialRedeemer`, `initialFeeManager` are the
  zero address (the zap injects the modules it creates), and `peripheryParams` is the placeholder from `TEMPLATE.json`
  (implem ids 0, init data `0x`); the encoder overwrites it in step 4. Never type encoded init data by hand.
- **Numbers:** write as JSON numbers when they fit in 53 bits, otherwise as decimal strings (`initialShareLimit`,
  `perfFeeRate`, `minRedeemAmount`). `vm.parseJsonUint` accepts both; strings avoid precision loss in editors.
- **Booleans:** `true` / `false` text becomes JSON booleans.
- **Lists:** comma-separated text or a JSON array in the cell becomes a JSON array; an empty cell for a list key
  (`initialBaseTokens`, `initialAccountingAgents`, `initialCreWorkflowIds`, `bridgeAdapterInitParams`) becomes `[]`.
  Do not add the accounting token to `initialBaseTokens`; the caliber adds it itself at initialisation.
- **Addresses:** copy as written (checksummed). `vm.parseJsonAddress` rejects a wrong-case checksum, so do not
  lowercase them.
- **Salt:** use the row's `Salt` if present. If empty, generate 32 random bytes (`openssl rand -hex 32`, prefix `0x`),
  write it into the file **and** into the row's Salt column with `notion-update-page`, so the record matches what will
  be scheduled. Salts must be unique per machine on the same chain.

Read one file back against `references/spcxc-example.md` to make sure the shape matches. Formatting comes after the
encode step (below), because the encoder rewrites the machine file.

## 4. Encode, schedule, execute

The scripts pick their files from env vars. For machine `T`:

```bash
export ZAP_OUTPUT_FILENAME=Base-Prod.json HUB_STRAT_INPUT_SUBDIR=create-machines \
  HUB_STRAT_INPUT_FILENAME=Base-T.json HUB_STRAT_OUTPUT_FILENAME=Base-T.json \
  DEPOSITOR_INPUT_FILENAME=Base-T.json REDEEMER_INPUT_FILENAME=Base-T.json FEE_MANAGER_INPUT_FILENAME=Base-T.json

forge script script/deployments/EncodePeripheryInitData.s.sol          # fills peripheryParams in the machine file
VIEW_ONLY=true forge script script/deployments/ScheduleCreateMachine.s.sol   # prints target + calldata for the zap owner safe
VIEW_ONLY=true forge script script/deployments/CreateMachine.s.sol           # prints target + calldata for the executor
```

Order of operations: write the files, run the encoder, then `yarn prettier:write` (the encoder's `vm.writeJson` output
is not prettier-clean and CI lints `**/*.json`), commit the diff for review, then schedule and create. The encoder only
touches the `peripheryParams` block (it fills the ids and init data and reorders its keys alphabetically); every other
key keeps the value and order you wrote.

Between scheduling and executing, the **values** in the machine file must not change: both scripts parse the file into
the same struct and hash the ABI-encoded payload, so a changed value means the executor's payload no longer matches
the scheduled one. Whitespace and key order are not part of that hash, so formatting is harmless, but the simplest
habit is to leave the file alone once scheduled.

View-only runs need no RPC or keys. To broadcast instead of printing calldata, drop `VIEW_ONLY` and add
`--rpc-url base --account <keystore> --broadcast` (owner for schedule, executor for create); that is when `.env` needs
`BASE_RPC_URL`. `CreateMachine` writes `script/deployments/outputs/create-machines/Base-T.json` with the machine and hub
caliber addresses.

## 5. Write results back

Update the Machines row: `Schedule tx`, `Create tx`, `Machine`, `Caliber`, and `Stage`. Depositor, redeemer and fee
manager addresses come from the machine's `depositor()`, `redeemer()`, `feeManager()` getters (`cast call`). Also hand
the non-chain columns (Description, Logo SVG, Logo PNG 200x200, oracle feed) to whoever lists the machine in the app.

## Worked example

`references/spcxc-example.md` holds the complete SPCXc case: the shared-table values, the four resulting files, and the
sha256 of the schedule calldata they produce. Reproducing that calldata is the regression check for this skill; do it
whenever the mapping rules or the repo scripts change.
