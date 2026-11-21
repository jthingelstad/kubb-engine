// Reading a folder of score sheets: what tools/realtiers.mjs and tools/batonvalue.mjs share
// (docs/notes/real-games.md). Planet Kubb Notation files go through pk-kubb-score's kubb.js
// (the copy in tests/vendor/pk-kubb-score); nothing here writes anywhere.

import { readFileSync, readdirSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));

export async function analyzer() {
  const kubb = join(here, '..', 'tests', 'vendor', 'pk-kubb-score', 'kubb.js');
  return (await import(pathToFileURL(kubb).href)).analyze;
}

// Every .txt in the folder, in name order, through kubb.js's analyze. `files` counts the
// .txt files; `games` keeps those with at least one turn, `names` their file names.
export async function loadGames(dir) {
  const analyze = await analyzer();
  const files = readdirSync(dir).filter(f => f.endsWith('.txt')).sort();
  const games = [], names = [];
  for (const f of files) {
    const g = analyze(readFileSync(join(dir, f), 'utf8'));
    if (g.rows.length) { games.push(g); names.push(f); }
  }
  return { files: files.length, games, names };
}

// A baton that was thrown: not X, not the batons kubb.js marks void (written after the game
// ended), not a resign or a win token (tools/realgames.mjs "How it counts").
export const thrown = b => !(b.void || b.kind === 'unthrown' || b.kind === 'resign' || b.kind === 'win');

// "Team Knockerheads" and "Knockerheads" are one team.
export const teamKey = s => (s || '').toLowerCase().replace(/^team\s+/, '').replace(/[^a-z0-9]/g, '');
