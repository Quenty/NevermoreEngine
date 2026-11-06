import * as fs from 'fs/promises';
import * as os from 'os';
import * as path from 'path';

const LAUNCH_MATCH_WINDOW_MS = 10_000;
const MAX_RECORDS = 50;

export interface StudioLaunchRecord {
  pid?: number;
  cwd: string;
  opened: string;
  launchedAt: number;
}

export function defaultLaunchRegistryPath(): string {
  return path.join(os.tmpdir(), 'studio-bridge', 'launches.json');
}

export async function recordStudioLaunchAsync(
  record: StudioLaunchRecord,
  registryPath = defaultLaunchRegistryPath()
): Promise<void> {
  const records = await readStudioLaunchesAsync(registryPath);
  records.push(record);
  await fs.mkdir(path.dirname(registryPath), { recursive: true });
  await fs.writeFile(
    registryPath,
    JSON.stringify(records.slice(-MAX_RECORDS), null, 2)
  );
}

export async function readStudioLaunchesAsync(
  registryPath = defaultLaunchRegistryPath()
): Promise<StudioLaunchRecord[]> {
  try {
    const parsed = JSON.parse(await fs.readFile(registryPath, 'utf-8'));
    return Array.isArray(parsed)
      ? parsed.filter(
          (r): r is StudioLaunchRecord =>
            r && typeof r.cwd === 'string' && typeof r.launchedAt === 'number'
        )
      : [];
  } catch {
    return [];
  }
}

export function findStudioLaunch(
  records: StudioLaunchRecord[],
  process: { pid: number; startedAt?: number }
): StudioLaunchRecord | undefined {
  const byPid = records.filter((r) => r.pid === process.pid);
  if (byPid.length > 0) {
    return byPid[byPid.length - 1];
  }
  if (process.startedAt === undefined) {
    return undefined;
  }
  const near = records.filter(
    (r) => Math.abs(r.launchedAt - process.startedAt!) <= LAUNCH_MATCH_WINDOW_MS
  );
  return near.length === 1 ? near[0] : undefined;
}
