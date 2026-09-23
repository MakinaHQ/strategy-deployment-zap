# Notion → deployment inputs

Tooling to turn the machine checklist tables in Notion into the JSON input files consumed by the deployment scripts in
`script/deployments/`. Built for the Dialectic Yielding xStocks launch (7 machines on Base identical to SPCXc), but
any checklist page with the same two tables works.

## Tables

Two Notion databases on the checklist page:

- **Machines**: one row per machine. Columns used by the export: `Name` (ticker, also the file name), `Accounting token
(Base)`, `Share token name`, `Share token symbol`, `Salt` (optional), `Inputs confirmed`, plus metadata columns
  (`Description`, `Logo SVG`, `Logo PNG 200x200`, `Oracle provider`, `Feed 1 address`, `Feed 1 decimals`,
  `Feed 1 staleness (s)`, `Feed 2 address`, `Feed 2 staleness (s)`, `Oracle registered`, `Stage`).
- **Shared Parameters**: one row per JSON field common to all machines. `Key` is a dotted path (`redeemer.finalizationDelay`,
  `machineInitParams.initialShareLimit`, ...), `Value` the raw on-chain value as text, `Confirmed` a checkbox. Lists are
  comma-separated or JSON arrays. The full key list is `REQUIRED_SHARED_KEYS` in `export-machines.mjs`; a filled example
  is `fixtures/spcxc.json`.

The export refuses to run while any machine row lacks `Inputs confirmed` or any shared row lacks `Confirmed`
(`--force` overrides, for dry runs).

## Setup

- `yarn` (prettier is used to format the generated JSON).
- `BASE_RPC_URL` in `.env` for broadcasting on Base (`base` alias in `foundry.toml`).
- `NOTION_TOKEN` in `.env`, from a Notion internal integration connected to the checklist page (below).
  `NOTION_MACHINES_DS` and `NOTION_SHARED_DS` override the data source ids (they default to the xStocks checklist
  tables).

### Notion internal integration (one-time)

The export reads the two tables over the Notion API with its own token. An internal integration only sees pages it
has been explicitly connected to, so the blast radius is the checklist page.

1. Go to <https://www.notion.so/profile/integrations> and create a new **internal** integration in the Makina
   workspace (e.g. `strategy-deployment-zap export`).
2. Capabilities: **Read content** only. Untick update, insert, comment and user information.
3. Copy the internal integration secret (starts with `ntn_`).
4. Open the checklist page in Notion, click the `...` menu, choose **Connections**, and add the integration. Access
   flows down to the databases on the page.
5. Put the secret in `.env` as `NOTION_TOKEN`. `.env` is gitignored; treat the token like the RPC keys in the same file.
6. Run `yarn notion:export --dry-run --force` and check it lists the expected machines.
7. Record who owns the integration so it can be rotated or removed after the launch.

## Usage

```
yarn notion:export                      # every machine row with Inputs confirmed
yarn notion:export --only AAPLc,MSFTc   # subset
yarn notion:export --dry-run            # list files without writing
yarn notion:export --fixture script/notion/fixtures/spcxc.json   # offline, from a local JSON
```

For each machine `T` this writes:

| File                                                         | Consumed by                      |
| ------------------------------------------------------------ | -------------------------------- |
| `script/deployments/inputs/create-machines/Base-T.json`      | Schedule/Create scripts          |
| `script/deployments/inputs/machine-depositors/Base-T.json`   | `EncodePeripheryInitData.s.sol`  |
| `script/deployments/inputs/machine-redeemers/Base-T.json`    | `EncodePeripheryInitData.s.sol`  |
| `script/deployments/inputs/machine-fee-managers/Base-T.json` | `EncodePeripheryInitData.s.sol`  |
| `script/notion/out/T.env`                                    | `run.sh` (env vars per machine)  |
| `script/notion/out/T.metadata.json`                          | App listing, oracle registration |

`peripheryParams` in the machine file is a placeholder until the encode step runs. The file prefix (`Base-`) and the zap
output filename (`Base-Prod.json`) can be changed with `MACHINE_FILE_PREFIX` and `ZAP_OUTPUT_FILENAME`.

If `Salt` is empty in Notion, the export derives one deterministically (`sha256("makina:strategy-deployment-zap:base:" +
shareTokenSymbol)`) and prints it. Paste it back into Notion so the record matches the deployment.

Then, per machine:

```
script/notion/run.sh AAPLc encode        # fills peripheryParams; review and commit the diff
script/notion/run.sh AAPLc schedule      # VIEW_ONLY: prints target + calldata for the zap owner safe
script/notion/run.sh AAPLc create        # VIEW_ONLY: prints target + calldata for the executor
```

Add `--broadcast --account <keystore>` to send directly (`--rpc-url base` is added automatically), e.g.
`script/notion/run.sh AAPLc create --broadcast --account executor`. Do not edit the machine input file between
scheduling and executing: both phases hash the same file.

## Regression check

`fixtures/spcxc.json` holds the SPCXc deployment. Exporting it and running the encode and schedule steps reproduces the
SPCXc `scheduleDeployment` calldata byte for byte, which is how the shared-parameter defaults were validated:

```
MACHINE_FILE_PREFIX=Check- yarn notion:export --fixture script/notion/fixtures/spcxc.json
script/notion/run.sh SPCXc encode
script/notion/run.sh SPCXc schedule
rm script/deployments/inputs/*/Check-SPCXc.json script/notion/out/SPCXc.*
```
