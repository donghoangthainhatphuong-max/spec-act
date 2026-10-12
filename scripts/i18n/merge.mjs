// Merge scripts/i18n/new.<lang>.json into src/locales/<lang>.json (sorted by key). Run: node scripts/i18n/merge.mjs
import fs from 'node:fs';
import path from 'node:path';

const dir = 'scripts/i18n';
for (const f of fs.readdirSync(dir)) {
  const m = /^new\.(\w+)\.json$/.exec(f);
  if (!m) continue;
  const target = `src/locales/${m[1]}.json`;
  const cur = JSON.parse(fs.readFileSync(target, 'utf8'));
  const add = JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8'));
  const merged = { ...cur, ...add };
  fs.writeFileSync(target, JSON.stringify(merged, null, 2) + '\n');
  console.log(m[1], Object.keys(add).length, 'keys merged');
}
