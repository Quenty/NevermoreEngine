import * as fs from 'fs/promises';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  CompositeResultReporter,
  FileResultReporter,
  StdoutResultReporter,
  formatJson,
  formatTable,
  type ResultReporter,
  type TableColumn,
} from '@quenty/cli-output-helpers/reporting';
import { getApiKeyAsync } from '@quenty/nevermore-cli-helpers';
import { NevermoreGlobalArgs } from '../../args/global-args.js';
import { discoverUniverseIdAsync } from '@quenty/nevermore-deploy';
import {
  formatAssetCreator,
  resolveAssetCreatorAsync,
} from '../../utils/assets/asset-creator.js';
import { type AssetType } from '../../utils/assets/asset-formats.js';
import {
  buildAssetUploadPlan,
  type AssetUploadPlanEntry,
} from '../../utils/assets/asset-upload-plan.js';
import {
  OpenCloudClient,
  type AssetCreator,
} from '../../utils/open-cloud/open-cloud-client.js';
import { RateLimiter } from '../../utils/open-cloud/rate-limiter.js';

export interface AssetUploadArgs extends NevermoreGlobalArgs {
  files?: string[];
  apiKey?: string;
  type?: AssetType;
  name?: string;
  description?: string;
  userId?: number;
  groupId?: number;
  assetId?: number;
  output?: string;
  timeout?: number;
}

/** What happened to one file. Written to `--output` as-is. */
export interface AssetUploadResult {
  file: string;
  assetType: AssetType;
  displayName: string;
  action: 'created' | 'updated';
  success: boolean;
  assetId?: number;
  /** `rbxassetid://<assetId>`, ready to paste into a content property. */
  assetUri?: string;
  revisionId?: string;
  moderationState?: string;
  error?: string;
}

export interface AssetUploadReport {
  /** Who owns the assets this run created. Absent when it only replaced one. */
  creator?: AssetCreator;
  assets: AssetUploadResult[];
}

function _plural(count: number): string {
  return count === 1 ? '' : 's';
}

function _action(entry: AssetUploadPlanEntry): AssetUploadResult['action'] {
  return entry.assetId == null ? 'created' : 'updated';
}

/**
 * Who will own the created assets, announced so an inferred owner is never a
 * surprise. Only a create needs one — replacing an asset's content leaves its
 * owner alone, so a run that is all `--asset-id` asks nobody.
 */
async function _resolveCreatorAsync(
  args: AssetUploadArgs,
  plan: AssetUploadPlanEntry[],
  client: OpenCloudClient
): Promise<AssetCreator | undefined> {
  if (plan.every((entry) => entry.assetId != null)) {
    return undefined;
  }

  const { creator, reason } = await resolveAssetCreatorAsync({
    userId: args.userId,
    groupId: args.groupId,
    universeId: await discoverUniverseIdAsync(process.cwd()),
    source: client,
    onFallback: (message) => OutputHelper.warn(message),
  });
  OutputHelper.info(`Owner: ${formatAssetCreator(creator)} (${reason})`);
  return creator;
}

async function _requireFilesAsync(plan: AssetUploadPlanEntry[]): Promise<void> {
  for (const entry of plan) {
    let isFile = false;
    try {
      isFile = (await fs.stat(entry.filePath)).isFile();
    } catch {
      // Reported below
    }
    if (!isFile) {
      throw new Error(`Cannot upload "${entry.filePath}": no such file.`);
    }
  }
}

async function _uploadAsync(
  client: OpenCloudClient,
  entry: AssetUploadPlanEntry,
  creator: AssetCreator | undefined,
  timeoutMs: number
): Promise<AssetUploadResult> {
  const result: AssetUploadResult = {
    file: entry.filePath,
    assetType: entry.assetType,
    displayName: entry.displayName,
    action: _action(entry),
    success: false,
  };

  try {
    const operation =
      entry.assetId != null
        ? await client.updateAssetContentAsync(entry.assetId, entry)
        : await client.createAssetAsync({ ...entry, creator: creator! });
    OutputHelper.verbose(`${entry.filePath}: waiting on ${operation.path}`);

    const asset = await client.pollAssetOperationAsync(operation, timeoutMs);
    return {
      ...result,
      success: true,
      assetId: asset.assetId,
      assetUri: `rbxassetid://${asset.assetId}`,
      revisionId: asset.revisionId,
      moderationState: asset.moderationState,
    };
  } catch (err) {
    return {
      ...result,
      error: OutputHelper.stripAnsi(
        err instanceof Error ? err.message : String(err)
      ),
    };
  }
}

function _renderTable(report: AssetUploadReport): string {
  const columns: TableColumn<AssetUploadResult>[] = [
    { header: 'File', value: (r) => r.file },
    { header: 'Type', value: (r) => r.assetType },
    {
      header: 'Result',
      value: (r) => (r.success ? r.action : 'FAILED'),
      format: (value, r) =>
        r.success ? value : OutputHelper.formatError(value),
    },
    { header: 'Asset', value: (r) => r.assetUri ?? '' },
    { header: 'Moderation', value: (r) => r.moderationState ?? '' },
  ];
  return formatTable(report.assets, columns);
}

function _buildReporter(
  outputPath: string | undefined
): ResultReporter<AssetUploadReport> {
  const reporters: ResultReporter<AssetUploadReport>[] = [
    new StdoutResultReporter({ render: _renderTable }),
  ];
  if (outputPath != null) {
    reporters.push(
      new FileResultReporter({
        outputPath,
        render: (report) => formatJson(report, { pretty: true }) + '\n',
      })
    );
  }
  return new CompositeResultReporter(reporters);
}

/**
 * `nevermore deploy asset upload <files..>` — upload files as Roblox assets
 * through the Open Cloud Assets API and print the id each one was given.
 *
 * Every file is attempted and reported, even after one fails. The assets that
 * did upload now exist, so their ids are the one thing a failed run must not
 * lose.
 */
export async function handleAssetUploadAsync(
  args: AssetUploadArgs
): Promise<void> {
  const plan = buildAssetUploadPlan({
    files: args.files ?? [],
    type: args.type,
    name: args.name,
    description: args.description,
    assetId: args.assetId,
  });
  await _requireFilesAsync(plan);

  // The key is only resolved when something asks for it, so a dryrun that was
  // told its owner still runs without credentials.
  const client = new OpenCloudClient({
    apiKey: () => getApiKeyAsync(args),
    rateLimiter: new RateLimiter(),
  });
  const creator = await _resolveCreatorAsync(args, plan, client);

  if (args.dryrun) {
    OutputHelper.info(
      `[DRYRUN] Would upload ${plan.length} asset${_plural(plan.length)}:`
    );
    const columns: TableColumn<AssetUploadPlanEntry>[] = [
      { header: 'File', value: (e) => e.filePath },
      { header: 'Type', value: (e) => e.assetType },
      { header: 'Name', value: (e) => e.displayName },
      {
        header: 'Action',
        value: (e) =>
          e.assetId == null ? 'create' : `replace asset ${e.assetId}`,
      },
    ];
    console.log(formatTable(plan, columns, { indent: '  ' }));
    return;
  }

  const timeoutMs = (args.timeout ?? 300) * 1000;

  OutputHelper.info(`Uploading ${plan.length} asset${_plural(plan.length)}...`);
  // The rate limiter caps how many of these are in flight at once.
  const report: AssetUploadReport = {
    creator,
    assets: await Promise.all(
      plan.map((entry) => _uploadAsync(client, entry, creator, timeoutMs))
    ),
  };

  const reporter = _buildReporter(args.output);
  await reporter.startAsync();
  reporter.onResult(report);
  await reporter.stopAsync();

  // An upload normally finishes while Roblox is still reviewing it, so this is
  // a note on the table rather than a warning per file.
  const unapproved = report.assets.filter(
    (asset) =>
      asset.success &&
      asset.moderationState != null &&
      !/approved$/i.test(asset.moderationState)
  );
  if (unapproved.length > 0) {
    OutputHelper.hint(
      `${unapproved.length} asset${_plural(unapproved.length)} not approved ` +
        `by moderation yet. The id is final, but the asset may not load until ` +
        `Roblox approves it.`
    );
  }

  // One bad key fails every file the same way, so identical errors are
  // reported once against all the files they hit.
  const filesByError = new Map<string, string[]>();
  for (const asset of report.assets) {
    if (!asset.success) {
      const error = asset.error ?? 'unknown error';
      filesByError.set(error, [...(filesByError.get(error) ?? []), asset.file]);
    }
  }
  for (const [error, files] of filesByError) {
    OutputHelper.error(`${files.join(', ')}: ${error}`);
  }
  if (filesByError.size > 0) {
    // Not process.exit(): on Windows, exiting while fetch's sockets are still
    // closing aborts Node with a libuv assertion and exit code 127.
    process.exitCode = 1;
  }
}
