// The Kubb Gym's helpers for running workers: a process pool, git, and an engine
// from a git ref in a temporary folder (docs/notes/gym.md).
import { spawn, execFileSync } from 'node:child_process';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

export const root = resolve(dirname(fileURLToPath(import.meta.url)), '..', '..');
export const LUA = process.env.LUA || 'lua5.4';

export function git(args, cwd = root) {
  try { return execFileSync('git', args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'ignore'] }).trim(); } catch { return null; }
}

// The engine (core, session, tune, pitch (room before 0.13), version.lua: those the ref has) of git ref `ref` into folder dir.
export function extractEngine(ref, dir) {
  const have = new Set((git(['ls-tree', '--name-only', ref]) || '').split('\n'));
  const paths = ['core', 'session', 'tune', 'pitch', 'room', 'version.lua'].filter(p => have.has(p));
  const tar = execFileSync('git', ['archive', ref, ...paths], { cwd: root, maxBuffer: 1 << 28 });
  execFileSync('tar', ['-x', '-C', dir], { input: tar });
}

// Runs tasks ({ args, cmd? }) on `jobs` processes; rejects on the first failure.
export function runPool(tasks, jobs, onDone) {
  return new Promise((ok, fail) => {
    let next = 0, running = 0, done = 0;
    const start = () => {
      while (running < jobs && next < tasks.length) {
        const t = tasks[next++];
        running++;
        const p = spawn(t.cmd || LUA, t.args, { cwd: root, stdio: ['ignore', 'pipe', 'pipe'] });
        let err = '';
        p.stderr.on('data', d => { err += d; });
        p.stdout.on('data', () => {});
        p.on('close', code => {
          running--;
          if (code !== 0) { fail(new Error(`gym: worker failed (${t.args.join(' ')}):\n${err}`)); return; }
          done++;
          if (onDone) onDone(done, tasks.length);
          if (done === tasks.length) ok(); else start();
        });
      }
    };
    if (!tasks.length) ok(); else start();
  });
}

