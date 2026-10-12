// Static checks: Lua syntax for .lua files, and sanity for .toc files.
//   node check.js ../*.lua ../*.toc
const fs = require('fs');
const path = require('path');
const luaparse = require('luaparse');

let bad = 0;

function checkLua(file) {
  try {
    luaparse.parse(fs.readFileSync(file, 'utf8'), { luaVersion: '5.1' });
    console.log('OK   ' + path.basename(file));
  } catch (err) {
    bad++;
    console.log('FAIL ' + path.basename(file) + ' :: ' + err.message);
  }
}

function checkToc(file) {
  const text = fs.readFileSync(file, 'utf8');
  // Resolved first, so a relative "../X.toc" does not report its folder as "..".
  const dir = path.dirname(path.resolve(file));
  const name = path.basename(file);
  const problems = [];

  // The folder name must match the TOC name, or the game will not load it.
  if (path.basename(dir) !== path.basename(file, '.toc')) {
    problems.push(`folder "${path.basename(dir)}" does not match the TOC name`);
  }

  for (const field of ['Interface', 'Title', 'Version']) {
    if (!new RegExp(`^##\\s*${field}\\s*:`, 'm').test(text)) {
      problems.push(`missing ## ${field}`);
    }
  }

  // Every listed file has to exist, and every .lua beside it should be listed.
  const listed = text
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith('#'));

  for (const entry of listed) {
    const target = path.join(dir, entry.replace(/\\/g, path.sep));
    if (!fs.existsSync(target)) problems.push(`lists a missing file: ${entry}`);
  }

  const listedSet = new Set(listed.map((e) => e.replace(/\\/g, '/').toLowerCase()));
  for (const onDisk of fs.readdirSync(dir)) {
    if (onDisk.toLowerCase().endsWith('.lua') && !listedSet.has(onDisk.toLowerCase())) {
      problems.push(`${onDisk} is on disk but not in the TOC`);
    }
  }

  const deps = text.match(/^##\s*(?:Required)?Dependencies\s*:\s*(.+)$/m);
  const optional = text.match(/^##\s*OptionalDeps\s*:\s*(.+)$/m);

  if (problems.length === 0) {
    const extra = [
      deps ? 'requires ' + deps[1].trim() : null,
      optional ? 'optionally uses ' + optional[1].trim() : null,
    ].filter(Boolean).join(', ');
    console.log('OK   ' + name + (extra ? ' (' + extra + ')' : ''));
  } else {
    bad++;
    for (const problem of problems) console.log('FAIL ' + name + ' :: ' + problem);
  }
}

for (const file of process.argv.slice(2)) {
  if (file.toLowerCase().endsWith('.toc')) checkToc(file);
  else checkLua(file);
}

process.exit(bad ? 1 : 0);
