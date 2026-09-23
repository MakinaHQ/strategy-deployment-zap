#!/usr/bin/env node
// Exports machine deployment inputs from the Notion checklist tables into this repo.
//
// Reads two Notion data sources (the "xStocks Machines" and "xStocks Shared Parameters" tables of the
// deployment checklist page) and writes, for every machine row:
//   script/deployments/inputs/create-machines/<PREFIX><Name>.json
//   script/deployments/inputs/machine-depositors/<PREFIX><Name>.json
//   script/deployments/inputs/machine-redeemers/<PREFIX><Name>.json
//   script/deployments/inputs/machine-fee-managers/<PREFIX><Name>.json
//   script/notion/out/<Name>.metadata.json   (description, logos, oracle: for the app / oracle registration)
//   script/notion/out/<Name>.env             (env vars consumed by script/notion/run.sh)
//
// `peripheryParams` is left as a placeholder; EncodePeripheryInitData.s.sol fills it (run.sh <T> encode).
//
// Env:   NOTION_TOKEN (required unless --fixture), NOTION_MACHINES_DS, NOTION_SHARED_DS,
//        MACHINE_FILE_PREFIX (default "Base-"), ZAP_OUTPUT_FILENAME (default "Base-Prod.json")
// Flags: --only A,B   export only these machine names
//        --force      ignore the "Inputs confirmed" / "Confirmed" checkboxes
//        --dry-run    print what would be written, write nothing
//        --fixture f  read rows from a local JSON file instead of Notion (see fixtures/)
//        --no-prettier
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { createHash } from "node:crypto";
import { dirname, join, relative, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { spawnSync } from "node:child_process";

const HERE = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(HERE, "../..");
const INPUTS = join(ROOT, "script/deployments/inputs");
const OUT = join(HERE, "out");

const NOTION_VERSION = "2025-09-03";
const DEFAULT_MACHINES_DS = "434a63fd-cb87-4ef8-8b57-707a6fd797ed";
const DEFAULT_SHARED_DS = "2aa96b7f-8a71-467d-89d3-6ee3dd316606";
const ZERO_ADDRESS = "0x" + "0".repeat(40);
const SALT_DOMAIN = "makina:strategy-deployment-zap:base:";

// Shared-table keys, grouped by the file / JSON node they land in.
const KEYS = {
  zap: ["executor", "delay"],
  root: [
    "setupAMFunctionRoles",
    "bridgeAdapterInitParams",
    "spokeSnapshotConsumerInitParams.initialCreWorkflowIds",
  ],
  depositor: ["implemId", "whitelist", "sanctionsCheck"],
  redeemer: [
    "implemId",
    "finalizationDelay",
    "minRedeemAmount",
    "whitelist",
    "sanctionsCheck",
  ],
  redeemerOptional: ["redeemFeeRate", "maxRedeemFeeRate"],
  feeManager: [
    "implemId",
    "mgmtFeeRatePerSecond",
    "smFeeRatePerSecond",
    "perfFeeRate",
    "mgmtFeeReceivers",
    "mgmtFeeSplitBps",
    "perfFeeReceivers",
    "perfFeeSplitBps",
  ],
  machineInitParams: [
    "initialCaliberStaleThreshold",
    "initialMaxFixedFeeAccrualRate",
    "initialMaxPerfFeeAccrualRate",
    "initialFeeMintCooldown",
    "initialShareLimit",
    "initialMaxSharePriceChangeRate",
  ],
  caliberInitParams: [
    "initialPositionStaleThreshold",
    "initialAllowedInstrRoot",
    "initialTimelockDuration",
    "initialMaxPositionIncreaseLossBps",
    "initialMaxPositionDecreaseLossBps",
    "initialMaxSwapLossBps",
    "initialCooldownDuration",
    "initialBaseTokens",
  ],
  makinaGovernableInitParams: [
    "initialMechanic",
    "initialSecurityCouncil",
    "initialRiskManager",
    "initialRiskManagerTimelock",
    "initialAuthority",
    "initialRestrictedAccountingMode",
    "initialAccountingAgents",
  ],
};

const ARRAY_KEYS = new Set([
  "bridgeAdapterInitParams",
  "spokeSnapshotConsumerInitParams.initialCreWorkflowIds",
  "feeManager.mgmtFeeReceivers",
  "feeManager.mgmtFeeSplitBps",
  "feeManager.perfFeeReceivers",
  "feeManager.perfFeeSplitBps",
  "caliberInitParams.initialBaseTokens",
  "makinaGovernableInitParams.initialAccountingAgents",
]);

const REQUIRED_SHARED_KEYS = [
  ...KEYS.zap.map((k) => `zap.${k}`),
  ...KEYS.root,
  ...KEYS.depositor.map((k) => `depositor.${k}`),
  ...KEYS.redeemer.map((k) => `redeemer.${k}`),
  ...KEYS.feeManager.map((k) => `feeManager.${k}`),
  ...KEYS.machineInitParams.map((k) => `machineInitParams.${k}`),
  ...KEYS.caliberInitParams.map((k) => `caliberInitParams.${k}`),
  ...KEYS.makinaGovernableInitParams.map(
    (k) => `makinaGovernableInitParams.${k}`,
  ),
];

// ---------------------------------------------------------------------------------------------------------------------
// CLI

function parseArgs(argv) {
  const args = {
    only: null,
    force: false,
    dryRun: false,
    fixture: null,
    prettier: true,
  };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--only")
      args.only = new Set(
        argv[++i]
          .split(",")
          .map((s) => s.trim())
          .filter(Boolean),
      );
    else if (a === "--force") args.force = true;
    else if (a === "--dry-run") args.dryRun = true;
    else if (a === "--fixture") args.fixture = argv[++i];
    else if (a === "--no-prettier") args.prettier = false;
    else if (a === "-h" || a === "--help") {
      console.log(
        readFileSync(fileURLToPath(import.meta.url), "utf8")
          .split("\n")
          .slice(1, 22)
          .join("\n"),
      );
      process.exit(0);
    } else throw new Error(`Unknown argument: ${a}`);
  }
  return args;
}

// ---------------------------------------------------------------------------------------------------------------------
// Notion

async function queryDataSource(id, token) {
  const rows = [];
  let cursor;
  do {
    const res = await fetch(
      `https://api.notion.com/v1/data_sources/${id}/query`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${token}`,
          "Notion-Version": NOTION_VERSION,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          page_size: 100,
          ...(cursor ? { start_cursor: cursor } : {}),
        }),
      },
    );
    if (!res.ok)
      throw new Error(
        `Notion query ${id} failed: ${res.status} ${await res.text()}`,
      );
    const json = await res.json();
    rows.push(...json.results.map(pageToRow));
    cursor = json.has_more ? json.next_cursor : undefined;
  } while (cursor);
  return rows;
}

function pageToRow(page) {
  const row = { _url: page.url };
  for (const [name, prop] of Object.entries(page.properties))
    row[name] = propertyValue(prop);
  return row;
}

function propertyValue(p) {
  switch (p.type) {
    case "title":
    case "rich_text":
      return p[p.type]
        .map((t) => t.plain_text)
        .join("")
        .trim();
    case "number":
      return p.number;
    case "checkbox":
      return p.checkbox;
    case "select":
      return p.select?.name ?? null;
    case "status":
      return p.status?.name ?? null;
    case "url":
      return p.url;
    case "files":
      return p.files.map((f) => ({
        name: f.name,
        url: f.type === "external" ? f.external.url : f.file?.url,
      }));
    default:
      return null;
  }
}

// ---------------------------------------------------------------------------------------------------------------------
// Value coercion

function scalar(raw) {
  const s = String(raw).trim();
  if (/^(true|false)$/i.test(s)) return s.toLowerCase() === "true";
  if (/^0x[0-9a-fA-F]*$/.test(s)) return s;
  if (/^-?\d+$/.test(s)) {
    const n = Number(s);
    return Number.isSafeInteger(n) ? n : s; // big uints stay strings; forge parseJsonUint accepts both
  }
  return s;
}

function coerce(key, raw) {
  const s = (raw ?? "").toString().trim();
  if (ARRAY_KEYS.has(key)) {
    if (s === "" || s === "[]") return [];
    if (s.startsWith("["))
      return JSON.parse(s).map((v) => (typeof v === "string" ? scalar(v) : v));
    return s
      .split(/[,\s]+/)
      .filter(Boolean)
      .map(scalar);
  }
  if (s === "") throw new Error(`Shared parameter "${key}" is empty`);
  return scalar(s);
}

function buildShared(rows, force) {
  const byKey = new Map();
  const unconfirmed = [];
  for (const r of rows) {
    const key = (r.Key ?? "").trim();
    if (!key) continue;
    if (byKey.has(key))
      throw new Error(`Duplicate shared parameter row: ${key}`);
    byKey.set(key, r);
    if (!r.Confirmed) unconfirmed.push(key);
  }
  const missing = REQUIRED_SHARED_KEYS.filter((k) => !byKey.has(k));
  if (missing.length)
    throw new Error(
      `Missing shared parameter rows:\n  ${missing.join("\n  ")}`,
    );
  if (unconfirmed.length && !force) {
    throw new Error(
      `Shared parameters not ticked "Confirmed" (use --force to ignore):\n  ${unconfirmed.join("\n  ")}`,
    );
  }
  return {
    get: (key) => coerce(key, byKey.get(key)?.Value),
    has: (key) =>
      byKey.has(key) && (byKey.get(key).Value ?? "").toString().trim() !== "",
  };
}

const pick = (shared, prefix, keys) =>
  Object.fromEntries(keys.map((k) => [k, shared.get(`${prefix}.${k}`)]));

// ---------------------------------------------------------------------------------------------------------------------
// Per-machine assembly

const isAddress = (s) => /^0x[0-9a-fA-F]{40}$/.test(s ?? "");
const isBytes32 = (s) => /^0x[0-9a-fA-F]{64}$/.test(s ?? "");

function deriveSalt(symbol) {
  return (
    "0x" +
    createHash("sha256")
      .update(SALT_DOMAIN + symbol)
      .digest("hex")
  );
}

function checkSplit(label, receivers, split) {
  if (receivers.length !== split.length)
    throw new Error(
      `${label}: receivers (${receivers.length}) and split (${split.length}) length mismatch`,
    );
  for (const r of receivers)
    if (!isAddress(r))
      throw new Error(`${label}: invalid receiver address ${r}`);
  const sum = split.reduce((a, b) => a + Number(b), 0);
  if (receivers.length && sum !== 10000)
    throw new Error(`${label}: split sums to ${sum}, expected 10000`);
}

function buildMachine(row, shared, force) {
  const name = (row.Name ?? "").trim();
  if (!name) throw new Error(`Machine row ${row._url} has no Name`);
  const fail = (msg) => new Error(`${name}: ${msg}`);

  if (!row["Inputs confirmed"] && !force)
    throw fail(`"Inputs confirmed" not ticked (use --force to ignore)`);

  const accountingToken = (row["Accounting token (Base)"] ?? "").trim();
  if (!isAddress(accountingToken))
    throw fail(`invalid accounting token address "${accountingToken}"`);
  const shareTokenName = (row["Share token name"] ?? "").trim();
  const shareTokenSymbol = (row["Share token symbol"] ?? "").trim();
  if (!shareTokenName || !shareTokenSymbol)
    throw fail("share token name and symbol are required");

  let salt = (row.Salt ?? "").trim();
  const saltDerived = salt === "";
  if (saltDerived) salt = deriveSalt(shareTokenSymbol);
  if (!isBytes32(salt)) throw fail(`salt must be 32-byte hex, got "${salt}"`);

  const machine = {
    executor: shared.get("zap.executor"),
    delay: shared.get("zap.delay"),
    peripheryParams: {
      depositorImplemId: 0,
      redeemerImplemId: 0,
      feeManagerImplemId: 0,
      depositorInitData: "0x",
      redeemerInitData: "0x",
      feeManagerInitData: "0x",
    },
    machineInitParams: {
      initialDepositor: ZERO_ADDRESS,
      initialRedeemer: ZERO_ADDRESS,
      initialFeeManager: ZERO_ADDRESS,
      ...pick(shared, "machineInitParams", KEYS.machineInitParams),
    },
    caliberInitParams: pick(
      shared,
      "caliberInitParams",
      KEYS.caliberInitParams,
    ),
    makinaGovernableInitParams: pick(
      shared,
      "makinaGovernableInitParams",
      KEYS.makinaGovernableInitParams,
    ),
    spokeSnapshotConsumerInitParams: {
      initialCreWorkflowIds: shared.get(
        "spokeSnapshotConsumerInitParams.initialCreWorkflowIds",
      ),
    },
    bridgeAdapterInitParams: shared.get("bridgeAdapterInitParams"),
    accountingToken,
    shareTokenName,
    shareTokenSymbol,
    salt,
    setupAMFunctionRoles: shared.get("setupAMFunctionRoles"),
  };
  if (!isAddress(machine.executor))
    throw fail(`invalid zap.executor ${machine.executor}`);

  const depositor = pick(shared, "depositor", KEYS.depositor);
  const redeemer = pick(shared, "redeemer", KEYS.redeemer);
  for (const k of KEYS.redeemerOptional)
    if (shared.has(`redeemer.${k}`)) redeemer[k] = shared.get(`redeemer.${k}`);
  if (
    redeemer.implemId === 2002 &&
    KEYS.redeemerOptional.some((k) => !(k in redeemer))
  ) {
    throw fail(
      "redeemer.implemId 2002 (AsyncRedeemerFee) needs redeemer.redeemFeeRate and redeemer.maxRedeemFeeRate rows",
    );
  }
  const feeManager = pick(shared, "feeManager", KEYS.feeManager);
  checkSplit(
    `${name}: mgmt fee`,
    feeManager.mgmtFeeReceivers,
    feeManager.mgmtFeeSplitBps,
  );
  checkSplit(
    `${name}: perf fee`,
    feeManager.perfFeeReceivers,
    feeManager.perfFeeSplitBps,
  );

  const metadata = {
    ticker: name,
    underlying: row.Underlying ?? "",
    accountingToken,
    tokenDecimals: row["Token decimals"] ?? null,
    shareTokenName,
    shareTokenSymbol,
    displayName: row["Display name"] ?? "",
    description: row.Description ?? "",
    logos: { svg: row["Logo SVG"] ?? [], png: row["Logo PNG 200x200"] ?? [] },
    oracle: {
      provider: row["Oracle provider"] ?? null,
      feed1: row["Feed 1 address"] || null,
      feed1Decimals: row["Feed 1 decimals"] ?? null,
      feed1StalenessSeconds: row["Feed 1 staleness (s)"] ?? null,
      feed2: row["Feed 2 address"] || null,
      feed2StalenessSeconds: row["Feed 2 staleness (s)"] ?? null,
      registered: Boolean(row["Oracle registered"]),
    },
    stage: row.Stage ?? null,
    notionUrl: row._url,
  };

  return {
    name,
    machine,
    depositor,
    redeemer,
    feeManager,
    metadata,
    salt,
    saltDerived,
  };
}

// ---------------------------------------------------------------------------------------------------------------------
// Output

function envFile(name, prefix, zapOutput) {
  const file = `${prefix}${name}.json`;
  return [
    `# generated by script/notion/export-machines.mjs for ${name}`,
    `ZAP_OUTPUT_FILENAME=${zapOutput}`,
    `HUB_STRAT_INPUT_SUBDIR=create-machines`,
    `HUB_STRAT_INPUT_FILENAME=${file}`,
    `HUB_STRAT_OUTPUT_FILENAME=${file}`,
    `DEPOSITOR_INPUT_FILENAME=${file}`,
    `REDEEMER_INPUT_FILENAME=${file}`,
    `FEE_MANAGER_INPUT_FILENAME=${file}`,
    "",
  ].join("\n");
}

function writeAll(built, { dryRun, prettier }) {
  const prefix = process.env.MACHINE_FILE_PREFIX ?? "Base-";
  const zapOutput = process.env.ZAP_OUTPUT_FILENAME ?? "Base-Prod.json";
  const written = [];
  const write = (path, content) => {
    written.push(path);
    if (dryRun) return;
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, content);
  };
  for (const b of built) {
    const file = `${prefix}${b.name}.json`;
    write(
      join(INPUTS, "create-machines", file),
      JSON.stringify(b.machine, null, 2) + "\n",
    );
    write(
      join(INPUTS, "machine-depositors", file),
      JSON.stringify(b.depositor, null, 2) + "\n",
    );
    write(
      join(INPUTS, "machine-redeemers", file),
      JSON.stringify(b.redeemer, null, 2) + "\n",
    );
    write(
      join(INPUTS, "machine-fee-managers", file),
      JSON.stringify(b.feeManager, null, 2) + "\n",
    );
    write(
      join(OUT, `${b.name}.metadata.json`),
      JSON.stringify(b.metadata, null, 2) + "\n",
    );
    write(join(OUT, `${b.name}.env`), envFile(b.name, prefix, zapOutput));
  }
  if (!dryRun && prettier) {
    const bin = join(ROOT, "node_modules/.bin/prettier");
    if (existsSync(bin)) {
      const jsonFiles = written.filter((f) => f.endsWith(".json"));
      const r = spawnSync(
        bin,
        ["--write", "--log-level", "warn", ...jsonFiles],
        { stdio: "inherit" },
      );
      if (r.status !== 0)
        console.warn(
          "prettier failed; run `yarn prettier:write` before committing",
        );
    } else
      console.warn(
        "node_modules/.bin/prettier not found (run `yarn`); run `yarn prettier:write` before committing",
      );
  }
  return written;
}

// ---------------------------------------------------------------------------------------------------------------------

async function loadRows(args) {
  if (args.fixture) {
    const fx = JSON.parse(readFileSync(resolve(args.fixture), "utf8"));
    return { machines: fx.machines, shared: fx.shared };
  }
  const token = process.env.NOTION_TOKEN;
  if (!token)
    throw new Error("NOTION_TOKEN is not set (or pass --fixture <file>)");
  const [machines, shared] = await Promise.all([
    queryDataSource(
      process.env.NOTION_MACHINES_DS ?? DEFAULT_MACHINES_DS,
      token,
    ),
    queryDataSource(process.env.NOTION_SHARED_DS ?? DEFAULT_SHARED_DS, token),
  ]);
  return { machines, shared };
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const { machines, shared: sharedRows } = await loadRows(args);
  const shared = buildShared(sharedRows, args.force);

  let rows = machines.filter((r) => (r.Name ?? "").trim() !== "");
  if (args.only) {
    rows = rows.filter((r) => args.only.has(r.Name.trim()));
    const found = new Set(rows.map((r) => r.Name.trim()));
    for (const n of args.only)
      if (!found.has(n)) throw new Error(`--only: no machine row named "${n}"`);
  }
  if (!rows.length) throw new Error("No machine rows to export");

  const built = rows.map((r) => buildMachine(r, shared, args.force));
  const written = writeAll(built, args);

  console.log(
    `${args.dryRun ? "Would write" : "Wrote"} ${written.length} files for ${built.length} machine(s):`,
  );
  for (const b of built) {
    const warn = [];
    if (b.saltDerived)
      warn.push("salt derived from share symbol (empty in Notion)");
    if (!b.metadata.oracle.registered) warn.push("oracle not registered");
    if (!b.metadata.description) warn.push("no description");
    if (!b.metadata.logos.svg.length || !b.metadata.logos.png.length)
      warn.push("logo missing");
    console.log(
      `  ${b.name.padEnd(8)} ${b.machine.shareTokenSymbol.padEnd(10)} ${b.machine.accountingToken}  salt=${b.salt}${warn.length ? `\n           ! ${warn.join("; ")}` : ""}`,
    );
  }
  if (args.dryRun)
    for (const f of written) console.log(`  ${relative(ROOT, f)}`);
  console.log(
    "\nNext: script/notion/run.sh <Name> encode   (fills peripheryParams), then review the diff.",
  );
}

main().catch((e) => {
  console.error(`error: ${e.message}`);
  process.exit(1);
});
