import * as fs from 'fs';
import * as path from 'path';
import { fileURLToPath } from 'url';

const packageRoot = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const source = path.join(
  packageRoot,
  '..',
  '..',
  'plugins',
  'studio-bridge-plugin'
);
const destination = path.join(packageRoot, 'studio-bridge-plugin');

fs.rmSync(destination, { recursive: true, force: true });
if (process.argv.includes('--clean')) {
  process.exit(0);
}

copyPackage(source, destination);

const { dependencies = {} } = readJson(path.join(source, 'package.json'));
for (const name of Object.keys(dependencies)) {
  copyPackage(
    fs.realpathSync(path.join(source, 'node_modules', name)),
    path.join(destination, 'node_modules', name)
  );
}
console.log(`Bundled the studio-bridge plugin into ${destination}`);

function copyPackage(from, to) {
  fs.mkdirSync(to, { recursive: true });
  for (const file of ['package.json', 'default.project.json']) {
    if (fs.existsSync(path.join(from, file))) {
      fs.copyFileSync(path.join(from, file), path.join(to, file));
    }
  }
  fs.cpSync(path.join(from, 'src'), path.join(to, 'src'), {
    recursive: true,
    dereference: true,
    filter: (file) => {
      const name = path.basename(file);
      return (
        name !== 'node_modules' &&
        !name.endsWith('.spec.lua') &&
        name !== 'jest.config.lua'
      );
    },
  });
}

function readJson(file) {
  return JSON.parse(fs.readFileSync(file, 'utf-8'));
}
