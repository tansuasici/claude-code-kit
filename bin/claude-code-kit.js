#!/usr/bin/env node
const { execFileSync } = require('child_process');
const { join } = require('path');

const cli = join(__dirname, 'cli.sh');
try {
  execFileSync('bash', [cli, ...process.argv.slice(2)], { stdio: 'inherit' });
} catch (e) {
  process.exit(e.status || 1);
}
