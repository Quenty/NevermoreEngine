import * as os from 'os';
import * as path from 'path';

export function getStateDir(): string {
  return path.join(os.tmpdir(), 'studio-bridge');
}
