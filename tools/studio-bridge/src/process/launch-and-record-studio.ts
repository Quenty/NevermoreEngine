import { launchStudioAsync } from './studio-process-manager.js';
import {
  recordStudioLaunchAsync,
  type StudioLaunchRecord,
} from './studio-launch-registry.js';

/** Launch Studio and record it for `process info`. Recording is best effort. */
export async function launchAndRecordStudioAsync(
  launch: Parameters<typeof launchStudioAsync>[0],
  record: Omit<StudioLaunchRecord, 'pid' | 'cwd' | 'launchedAt'>,
  cwd = process.cwd()
): Promise<void> {
  const launchedAt = Date.now();
  const studio = await launchStudioAsync(launch);
  await recordStudioLaunchAsync({
    pid: studio?.process?.pid,
    cwd,
    launchedAt,
    ...record,
  }).catch(() => {});
}
