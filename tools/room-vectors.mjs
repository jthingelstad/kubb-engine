#!/usr/bin/env node
// Regenerate tests/room/vectors/ from the web's JavaScript (docs/ROOM.md "Equivalence").
//
//   node tools/room-vectors.mjs [--web <dir>] [--commit <sha>]
//
// <dir> is a kubb.thingelstad.xyz checkout or export holding src/net/{lobby,seats,sync}.js
// (default: $KUBB_WEB, else the sibling checkout ../kubb.thingelstad.xyz). The commit
// recorded in the vectors is --commit, else the checkout's HEAD. Read only: nothing is
// written there.
import { execFileSync } from "node:child_process";
import { existsSync, mkdirSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";
import { generate, jsAdapter } from "./room-scenarios.mjs";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const OUT = join(ROOT, "tests/room/vectors");

export function webDir(arg) {
  return resolve(arg || process.env.KUBB_WEB || join(ROOT, "../kubb.thingelstad.xyz"));
}

export async function loadWeb(dir) {
  const net = join(dir, "src/net");
  if (!existsSync(join(net, "lobby.js"))) return null;
  const imp = (f) => import(pathToFileURL(join(net, f)).href);
  const [lobby, seats, sync] = await Promise.all([imp("lobby.js"), imp("seats.js"), imp("sync.js")]);
  return { lobby, seats, sync };
}

export function headOf(dir) {
  try {
    return execFileSync("git", ["-C", dir, "rev-parse", "HEAD"], { encoding: "utf8" }).trim();
  } catch {
    return null;
  }
}

async function main() {
  const args = process.argv.slice(2);
  const opt = (k) => {
    const i = args.indexOf(k);
    return i >= 0 ? args[i + 1] : undefined;
  };
  const dir = webDir(opt("--web"));
  const web = await loadWeb(dir);
  if (!web) throw new Error(`no src/net/lobby.js under ${dir}`);
  const commit = opt("--commit") || headOf(dir);
  if (!commit) throw new Error("no web commit: pass --commit <sha>");
  const scenarios = generate(jsAdapter(web));
  rmSync(OUT, { recursive: true, force: true });
  mkdirSync(OUT, { recursive: true });
  let steps = 0;
  const index = [];
  scenarios.forEach((s, i) => {
    const file = `${String(i + 1).padStart(3, "0")}-${s.name.replace(/[^a-z0-9]+/gi, "-").toLowerCase()}.json`;
    const doc = { name: s.name, web: commit, start: s.start, steps: s.steps };
    writeFileSync(join(OUT, file), JSON.stringify(doc) + "\n");
    index.push(file);
    steps += s.steps.length;
  });
  writeFileSync(join(OUT, "index.json"), JSON.stringify({ web: commit, scenarios: index, steps }, null, 1) + "\n");
  console.log(`${index.length} scenarios, ${steps} steps, from web ${commit.slice(0, 12)}`);
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) await main();
