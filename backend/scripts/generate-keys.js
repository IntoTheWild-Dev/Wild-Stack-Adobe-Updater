#!/usr/bin/env node
// Usage: node scripts/generate-keys.js <ae|id|ps> [count]
// Prints SQL you can run with: wrangler d1 execute wildstack-licenses --remote --command="..."
//
// Example: node scripts/generate-keys.js ae 5

const { randomBytes } = require('crypto');

const PLUGIN_MAP = {
  ae: 'com.wildagency.aestackcompswap',
  id: 'com.wildagency.idstackautoupdate',
  ps: 'com.wildstack.psassetswap',
};

const prefixArg = process.argv[2]?.toLowerCase();
const count = parseInt(process.argv[3] || '10', 10);

if (!prefixArg || !PLUGIN_MAP[prefixArg]) {
  console.error('Usage: node scripts/generate-keys.js <ae|id|ps> [count]');
  console.error('Example: node scripts/generate-keys.js ae 5');
  process.exit(1);
}

const prefix = prefixArg.toUpperCase();
const pluginId = PLUGIN_MAP[prefixArg];

const keys = Array.from({ length: count }, () => {
  const segments = Array.from({ length: 3 }, () =>
    randomBytes(2).toString('hex').toUpperCase()
  );
  return `WS-${prefix}-${segments.join('-')}`;
});

const values = keys.map(k => `('${k}', '${pluginId}')`).join(',\n  ');
const sql = `INSERT INTO license_keys (id, plugin_id) VALUES\n  ${values};`;

console.log(`\n-- ${count} keys for ${pluginId}\n`);
console.log(sql);
console.log('\n-- To insert, run:');
console.log(`-- wrangler d1 execute wildstack-licenses --remote --command="${sql.replace(/\n/g, ' ')}"`);
console.log('\n-- Keys generated:');
keys.forEach(k => console.log(k));
