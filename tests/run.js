// Runs the tests under fengari, a Lua VM for node.
//
//   node run.js            every test file here
//   node run.js frames     just tests/frames.lua
//
// Each test file is handed the addon's folder and the text of its .toc - fengari
// has no `io`, so the Lua side cannot read the .toc for itself.
const fs = require('fs');
const path = require('path');
const { lua, lauxlib, lualib, to_luastring } = require('fengari');

const addonPath = path.resolve(__dirname, '..');
const toc = fs.readFileSync(path.join(addonPath, 'DogsForeverUI.toc'), 'utf8');

const ALL = ['core', 'fonts', 'frames', 'party', 'nameplates', 'castbar', 'fsr', 'combo', 'xp', 'mirror', 'flight', 'loot', 'minimap', 'objectives', 'cooldowns', 'threat', 'toasts', 'totems', 'chat', 'menus', 'buttons', 'reporter', 'fishing', 'skinning',
  'options', 'snap', 'layouts', 'actionbars', 'places', 'chatlook', 'keybinds', 'gamedefaults', 'install', 'retail', 'classpower'];
const wanted = process.argv.slice(2);
const names = wanted.length ? wanted : ALL;

let failed = 0;
for (const name of names) {
  const file = path.join(__dirname, name + '.lua');
  console.log('\n######## ' + name);

  const L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);

  if (lauxlib.luaL_loadfile(L, to_luastring(file)) !== lua.LUA_OK) {
    console.error('load error: ' + lua.lua_tojsstring(L, -1));
    failed++;
    continue;
  }

  lua.lua_pushstring(L, to_luastring(addonPath.replace(/\\/g, '/')));
  lua.lua_pushstring(L, to_luastring(toc));

  if (lua.lua_pcall(L, 2, 0, 0) !== lua.LUA_OK) {
    console.error('runtime error: ' + lua.lua_tojsstring(L, -1));
    failed++;
  }
}

console.log(failed ? `\n${failed} TEST FILE(S) FAILED` : '\nEVERY TEST FILE PASSED');
process.exit(failed ? 1 : 0);
