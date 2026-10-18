import { spawnSync } from 'node:child_process';
import { existsSync, mkdirSync, copyFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const root = dirname(dirname(fileURLToPath(import.meta.url)));
const executable = process.platform === 'win32' ? 'moon.exe' : 'moon';
const configured = process.env.MOON_HOME;
const local = configured ? join(configured, 'bin', executable) : null;
const moon = local && existsSync(local) ? local : executable;
for (const target of ['', 'webui', 'cmd/moontourney']) {
  const args = ['build', ...(target ? [target] : []), '--target', 'js', '--release', '--deny-warn'];
  const result = spawnSync(moon, args, { cwd: root, stdio: 'inherit' });
  if (result.error || result.status !== 0) {
    console.error(result.error?.message ?? 'MoonBit build failed.');
    process.exit(result.status || 1);
  }
}
const dist = join(root, 'dist');
mkdirSync(dist, { recursive: true });
for (const name of ['index.html', 'style.css']) copyFileSync(join(root, 'web', name), join(dist, name));
const outputs = [['webui/webui.js', 'ui.mjs'], ['cmd/moontourney/moontourney.js', 'moontourney.mjs'], ['core.js', 'engine.mjs']];
for (const [source, destination] of outputs) copyFileSync(join(root, '_build/js/release/build', source), join(dist, destination));
console.log('Built dist/: web app, CLI, and portable engine.');
