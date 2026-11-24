import * as fs from 'fs/promises';
import * as os from 'os';
import * as path from 'path';
import { execa } from 'execa';
import inquirer from 'inquirer';
import { CommandModule } from 'yargs';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { formatCount } from '@quenty/cli-output-helpers/reporting';
import { NevermoreGlobalArgs } from '../../args/global-args.js';
import {
  DEFAULT_NPM_REGISTRY,
  checkRegistryAsync,
  findGitRootAsync,
  findPublishWorkflowsAsync,
  getGithubTrustStatus,
  isNpmTrustSupported,
  isTransientNpmFailure,
  packageExistsOnRegistryAsync,
  parseGithubRepository,
  parseTrustListJson,
  selectPackages,
  withRetriesAsync,
  type GithubTrustTarget,
  type NpmTrustConfig,
  type RegistryCheckResult,
} from '../../utils/npm/npm-trust-utils.js';
import {
  findPackageContainingAsync,
  findWorkspaceRootAsync,
  listPublishablePackagesAsync,
  type PublishablePackage,
} from '../../utils/workspace-utils.js';

interface NpmTrustArgs extends NevermoreGlobalArgs {
  packages: string[];
  check: boolean;
  repository?: string;
  workflow?: string;
  registry?: string;
}

interface TrustJob {
  pkg: PublishablePackage;
  target: GithubTrustTarget;
  registry: string;
}

/** npm's documented rate-limit guidance for bulk `npm trust` calls. */
const TRUST_CREATE_DELAY_MS = 2000;
const TRUST_LOOKUP_CONCURRENCY = 8;

/** Collects per-package failures so one bad package never stops the rest. */
class FailureLog {
  private readonly _reasons = new Map<string, string>();

  public add(name: string, reason: string): void {
    this._reasons.set(name, reason);
    OutputHelper.warn(`${name}: ${reason}`);
  }

  public has(name: string): boolean {
    return this._reasons.has(name);
  }

  public get names(): string[] {
    return [...this._reasons.keys()];
  }
}

class NeedsTwoFactorError extends Error {}

/**
 * Releases publish through npm trusted publishing (OIDC from a GitHub Actions
 * workflow), which only works for packages that already exist on npm and
 * trust that workflow. This command closes the gap for new packages: publish
 * their first version from your machine, then trust the workflow.
 *
 * `--check` is the unauthenticated half that CI runs before releasing, so a
 * release fails up front with instructions instead of partway through.
 */
export const npmTrustCommand: CommandModule<NevermoreGlobalArgs, NpmTrustArgs> =
  {
    command: 'npm-trust [packages..]',
    describe:
      'Publish first versions of new packages and configure npm trusted publishing for the release workflow',
    builder: (yargs) => {
      return yargs
        .positional('packages', {
          describe:
            'Packages by name (@scope/pkg) or directory name. Defaults to the package in the current directory, or every publishable package from the workspace root.',
          type: 'string',
          array: true,
          default: [],
        })
        .option('check', {
          describe:
            'Only verify every publishable package exists on its registry (no auth needed). Exits 1 if any are missing.',
          type: 'boolean',
          default: false,
        })
        .option('repository', {
          describe:
            "GitHub repository allowed to publish (owner/repo). Defaults to each package's repository field.",
          type: 'string',
        })
        .option('workflow', {
          describe:
            'Workflow file allowed to publish. Defaults to the one workflow in .github/workflows that publishes with id-token: write.',
          type: 'string',
        })
        .option('registry', {
          describe:
            "Registry to use for packages without publishConfig.registry. Defaults to npm's configured registry.",
          type: 'string',
        }) as any;
    },
    handler: async (args) => {
      try {
        const exitCode = await _runAsync(args);
        if (exitCode !== 0) {
          process.exit(exitCode);
        }
      } catch (err) {
        OutputHelper.error(err instanceof Error ? err.message : String(err));
        process.exit(1);
      }
    },
  };

async function _runAsync(args: NpmTrustArgs): Promise<number> {
  const cwd = process.cwd();
  const packages = await _resolvePackagesAsync(args, cwd);
  if (packages.length === 0) {
    OutputHelper.info('No publishable packages found.');
    return 0;
  }

  const defaultRegistry = args.registry ?? (await _getNpmRegistryAsync());
  const registryCheck = await checkRegistryAsync(packages, defaultRegistry);

  if (args.check) {
    return _reportCheck(packages, registryCheck);
  }

  await _ensureNpmReadyAsync();
  const failures = new FailureLog();

  for (const { pkg, error } of registryCheck.unknown) {
    failures.add(pkg.name, `could not reach the registry (${error})`);
  }

  // Resolve trust targets before publishing anything, so a package that can't
  // be trusted isn't left published without trust.
  const workflow = args.workflow ?? (await _detectWorkflowAsync(cwd));
  const jobs: TrustJob[] = [];
  for (const pkg of packages) {
    if (failures.has(pkg.name)) {
      continue;
    }
    const repository = args.repository ?? parseGithubRepository(pkg.repository);
    if (!repository) {
      failures.add(
        pkg.name,
        'no GitHub repository in package.json. Set "repository" or pass --repository.'
      );
      continue;
    }
    jobs.push({
      pkg,
      target: { repository, file: workflow },
      registry: pkg.registry ?? defaultRegistry,
    });
  }

  const missing = new Set(registryCheck.missing.map((pkg) => pkg.name));
  const toPublish = jobs.filter((job) => missing.has(job.pkg.name));
  if (toPublish.length > 0) {
    await _publishFirstVersionsAsync(toPublish, args, failures);
  }

  const toTrust = jobs.filter((job) => !failures.has(job.pkg.name));
  await _configureTrustAsync(toTrust, args, failures);

  if (failures.names.length > 0) {
    OutputHelper.hint(
      `Re-run for the failures: nevermore tools npm-trust ${failures.names.join(
        ' '
      )}`
    );
    return 1;
  }
  return 0;
}

/**
 * Explicit names win. Otherwise, run inside a package directory it means that
 * package; run from the workspace root it means every publishable package.
 */
async function _resolvePackagesAsync(
  args: NpmTrustArgs,
  cwd: string
): Promise<PublishablePackage[]> {
  const all = await listPublishablePackagesAsync(cwd);
  if (args.packages.length > 0) {
    return selectPackages(all, args.packages);
  }

  const root = await findWorkspaceRootAsync(cwd);
  const containing = await findPackageContainingAsync(all, cwd, root);
  if (containing) {
    OutputHelper.info(
      `Using ${containing.name} (the package in this directory). Run from ${root} for every package.`
    );
    return [containing];
  }
  return all;
}

function _reportCheck(
  packages: PublishablePackage[],
  result: RegistryCheckResult<PublishablePackage>
): number {
  for (const { pkg, error } of result.unknown) {
    // A registry blip shouldn't block a release; lerna will hit the same wall
    // and fail loudly if it's real.
    OutputHelper.warn(`Could not check ${pkg.name}: ${error}`);
  }

  // Trusted publishing attaches provenance, and npm rejects provenance unless
  // repository.url names the repo that built it, so the publish fails.
  const withoutRepository = packages.filter(
    (pkg) => !parseGithubRepository(pkg.repository)
  );
  if (withoutRepository.length > 0) {
    OutputHelper.error(
      `${formatCount(
        withoutRepository.length,
        'package has',
        'packages have'
      )} no GitHub "repository" in package.json, which trusted publishing needs:\n` +
        withoutRepository.map((pkg) => `  ${pkg.name}`).join('\n')
    );
  }

  if (result.missing.length === 0) {
    if (withoutRepository.length > 0) {
      return 1;
    }
    OutputHelper.info(
      `${formatCount(
        packages.length - result.unknown.length,
        'checked package exists',
        'checked packages exist'
      )} on the registry.`
    );
    return 0;
  }

  const names = result.missing.map((pkg) => pkg.name);
  OutputHelper.error(
    `${formatCount(
      names.length,
      'package is',
      'packages are'
    )} not on the registry yet. Trusted publishing can't create new packages:\n` +
      names.map((name) => `  ${name}`).join('\n')
  );
  OutputHelper.hint(
    `Publish the first version and trust the release workflow from your machine:\n  nevermore tools npm-trust ${names.join(
      ' '
    )}`
  );
  return 1;
}

async function _getNpmRegistryAsync(): Promise<string> {
  try {
    const { stdout } = await execa('npm', ['config', 'get', 'registry']);
    return stdout.trim() || DEFAULT_NPM_REGISTRY;
  } catch {
    return DEFAULT_NPM_REGISTRY;
  }
}

async function _detectWorkflowAsync(cwd: string): Promise<string> {
  const gitRoot = await findGitRootAsync(cwd);
  if (!gitRoot) {
    throw new Error(
      'Not in a git repository. Pass --workflow and --repository.'
    );
  }

  const candidates = await findPublishWorkflowsAsync(gitRoot);
  if (candidates.length === 1) {
    OutputHelper.verbose(`Using publish workflow ${candidates[0]}`);
    return candidates[0];
  }
  if (candidates.length === 0) {
    throw new Error(
      'No workflow in .github/workflows publishes with "id-token: write". Add that permission to your release workflow, or pass --workflow.'
    );
  }
  throw new Error(
    `Several workflows could publish (${candidates.join(
      ', '
    )}). Pass --workflow to pick one.`
  );
}

async function _ensureNpmReadyAsync(): Promise<void> {
  const { stdout: npmVersion } = await execa('npm', ['--version']);
  if (!isNpmTrustSupported(npmVersion)) {
    throw new Error(
      `npm ${npmVersion.trim()} can't manage trusted publishing. Update with: npm install -g npm@latest`
    );
  }

  try {
    const { stdout } = await execa('npm', ['whoami']);
    OutputHelper.verbose(`Logged in to npm as ${stdout.trim()}`);
  } catch {
    throw new Error('Not logged in to npm. Run: npm login');
  }
}

function _registryArgs(registry: string): string[] {
  return registry === DEFAULT_NPM_REGISTRY ? [] : ['--registry', registry];
}

async function _publishFirstVersionsAsync(
  jobs: TrustJob[],
  args: NpmTrustArgs,
  failures: FailureLog
): Promise<void> {
  OutputHelper.info(
    `${formatCount(
      jobs.length,
      'package is',
      'packages are'
    )} not on the registry yet:\n` +
      jobs.map(({ pkg }) => `  ${pkg.name}@${pkg.version}`).join('\n')
  );

  if (args.dryrun) {
    OutputHelper.info('Dry run: would publish the first version of each.');
    return;
  }

  if (!args.yes) {
    const { proceed } = await inquirer.prompt([
      {
        type: 'confirm',
        name: 'proceed',
        message:
          'Publish these versions from this machine? npm will ask for 2FA.',
        default: true,
      },
    ]);
    if (!proceed) {
      for (const { pkg } of jobs) {
        failures.add(
          pkg.name,
          'first publish skipped, so it cannot be trusted yet'
        );
      }
      return;
    }
  }

  const packDir = await fs.mkdtemp(
    path.join(os.tmpdir(), 'nevermore-npm-trust-')
  );
  try {
    for (const [index, job] of jobs.entries()) {
      OutputHelper.info(
        `[${index + 1}/${jobs.length}] Publishing ${job.pkg.name}@${
          job.pkg.version
        }`
      );
      try {
        await _publishFirstVersionAsync(job, packDir);
      } catch (err) {
        failures.add(
          job.pkg.name,
          `first publish failed (${err instanceof Error ? err.message : err})`
        );
      }
    }
  } finally {
    await fs.rm(packDir, { recursive: true, force: true });
  }
}

async function _publishFirstVersionAsync(
  job: TrustJob,
  packDir: string
): Promise<void> {
  const tarball = await _packAsync(job.pkg, packDir);
  const maxAttempts = 2;
  for (let attempt = 1; ; attempt++) {
    try {
      // inherit stdio so npm's 2FA prompt reaches the terminal
      await execa(
        'npm',
        [
          'publish',
          tarball,
          '--access',
          'public',
          ..._registryArgs(job.registry),
        ],
        { stdio: 'inherit' }
      );
      return;
    } catch (err) {
      // A publish can land even when the response doesn't make it back
      if (await _existsQuietlyAsync(job)) {
        return;
      }
      if (attempt >= maxAttempts) {
        throw err;
      }
      OutputHelper.warn(`Publishing ${job.pkg.name} failed, retrying`);
    }
  }
}

async function _existsQuietlyAsync(job: TrustJob): Promise<boolean> {
  try {
    return await packageExistsOnRegistryAsync(job.pkg.name, job.registry);
  } catch {
    return false;
  }
}

/**
 * Packs with the workspace's own tool: `pnpm pack` rewrites `workspace:`
 * dependency ranges to real versions, which npm would ship verbatim.
 */
async function _packAsync(
  pkg: PublishablePackage,
  packDir: string
): Promise<string> {
  const usesWorkspaceProtocol = await _usesWorkspaceProtocolAsync(pkg);
  const before = new Set(await fs.readdir(packDir));
  await execa(
    usesWorkspaceProtocol ? 'pnpm' : 'npm',
    ['pack', '--pack-destination', packDir],
    { cwd: pkg.path }
  );
  const created = (await fs.readdir(packDir)).find(
    (file) => file.endsWith('.tgz') && !before.has(file)
  );
  if (!created) {
    throw new Error(`packing produced no tarball for ${pkg.name}`);
  }
  return path.join(packDir, created);
}

async function _usesWorkspaceProtocolAsync(
  pkg: PublishablePackage
): Promise<boolean> {
  const contents = await fs.readFile(
    path.join(pkg.path, 'package.json'),
    'utf-8'
  );
  return contents.includes('"workspace:');
}

/**
 * npm only prompts for 2FA when stdout is a terminal, and parsing the list
 * means piping stdout. So on a 2FA demand, an interactive read runs the same
 * list attached to the terminal to get through 2FA (and its 5-minute skip),
 * then reads it again. A non-interactive read throws instead.
 */
async function _readTrustConfigsAsync(
  job: TrustJob,
  interactive: boolean
): Promise<NpmTrustConfig[]> {
  const args = [
    'trust',
    'list',
    job.pkg.name,
    '--json',
    ..._registryArgs(job.registry),
  ];
  const readAsync = () =>
    withRetriesAsync(
      async () => {
        const result = await execa('npm', args, { reject: false });
        const output = `${result.stdout}\n${result.stderr}`;
        if (result.exitCode !== 0 && isTransientNpmFailure(output)) {
          throw new Error(output);
        }
        return result;
      },
      { isRetryable: () => true }
    );

  let result = await readAsync();
  if (result.exitCode !== 0 && result.stdout.includes('EOTP')) {
    if (!interactive) {
      throw new NeedsTwoFactorError();
    }
    if (!process.stdin.isTTY || !process.stdout.isTTY) {
      throw new Error(
        'npm needs 2FA, which needs an interactive terminal. Run this from a terminal.'
      );
    }
    OutputHelper.info(
      'npm needs 2FA. Approve in the browser and choose to skip 2FA for 5 minutes.'
    );
    await execa(
      'npm',
      ['trust', 'list', job.pkg.name, ..._registryArgs(job.registry)],
      {
        stdio: 'inherit',
      }
    );
    result = await readAsync();
  }

  if (result.exitCode !== 0) {
    throw new Error(
      (result.stderr || result.stdout)
        .split('\n')
        .find((line) => line.trim()) ??
        `npm trust list exited ${result.exitCode}`
    );
  }
  return parseTrustListJson(result.stdout);
}

/**
 * Reads every package's trust config: one interactive read to get through
 * 2FA, then the rest in parallel while the 2FA skip window is open. Reads
 * that hit an expired window are redone one at a time, interactively.
 */
async function _readAllTrustConfigsAsync(
  jobs: TrustJob[],
  failures: FailureLog
): Promise<Map<string, NpmTrustConfig[]>> {
  const configs = new Map<string, NpmTrustConfig[]>();
  const deferred: TrustJob[] = [];

  const readOneAsync = async (job: TrustJob, interactive: boolean) => {
    try {
      configs.set(job.pkg.name, await _readTrustConfigsAsync(job, interactive));
    } catch (err) {
      if (err instanceof NeedsTwoFactorError) {
        deferred.push(job);
      } else {
        failures.add(
          job.pkg.name,
          `could not read trust config (${
            err instanceof Error ? err.message : err
          })`
        );
      }
    }
  };

  const [first, ...rest] = jobs;
  if (!first) {
    return configs;
  }
  await readOneAsync(first, true);

  let next = 0;
  await Promise.all(
    Array.from({ length: TRUST_LOOKUP_CONCURRENCY }, async () => {
      while (next < rest.length) {
        await readOneAsync(rest[next++], false);
      }
    })
  );

  for (const job of deferred.splice(0)) {
    await readOneAsync(job, true);
  }
  return configs;
}

async function _configureTrustAsync(
  jobs: TrustJob[],
  args: NpmTrustArgs,
  failures: FailureLog
): Promise<void> {
  if (jobs.length === 0) {
    return;
  }

  OutputHelper.info(
    `Reading trusted publishing config for ${formatCount(
      jobs.length,
      'package',
      'packages'
    )}. When npm asks for 2FA, choose to skip 2FA for 5 minutes.`
  );
  const configs = await _readAllTrustConfigsAsync(jobs, failures);

  let alreadyTrusted = 0;
  let mismatched = 0;
  const toCreate: TrustJob[] = [];
  for (const job of jobs) {
    const existing = configs.get(job.pkg.name);
    if (!existing) {
      continue; // read failed, already logged
    }
    const status = getGithubTrustStatus(existing, job.target);
    if (status === 'trusted') {
      alreadyTrusted++;
    } else if (status === 'mismatched') {
      // Replacing someone else's config is a decision, not a fix-up
      OutputHelper.warn(
        `${job.pkg.name} trusts a different publisher; leaving it alone. See: npm trust list ${job.pkg.name}`
      );
      mismatched++;
    } else {
      toCreate.push(job);
    }
  }

  let created = 0;
  for (const [index, job] of toCreate.entries()) {
    const progress = `[${index + 1}/${toCreate.length}]`;
    if (args.dryrun) {
      OutputHelper.info(
        `${progress} Dry run: would trust ${job.target.repository} ${job.target.file} for ${job.pkg.name}`
      );
      created++;
      continue;
    }

    OutputHelper.info(
      `${progress} Trusting ${job.target.file} for ${job.pkg.name}`
    );
    if (await _createTrustAsync(job)) {
      created++;
    } else {
      failures.add(job.pkg.name, 'could not configure trusted publishing');
    }
    await new Promise((resolve) => setTimeout(resolve, TRUST_CREATE_DELAY_MS));
  }

  OutputHelper.info(
    [
      `${formatCount(alreadyTrusted, 'package', 'packages')} already trusted`,
      `${formatCount(created, 'package', 'packages')} ${
        args.dryrun ? 'to configure' : 'configured'
      }`,
      `${formatCount(
        mismatched,
        'package',
        'packages'
      )} with a different publisher`,
    ].join(', ')
  );

  if (created > 0 && !args.dryrun) {
    OutputHelper.hint(
      'npm expires a new trust configuration if no publish uses it soon (about 2 days). Release these packages promptly.'
    );
  }
}

/**
 * Creates are not idempotent, so after a failure the config is re-read: a
 * create that landed despite the error counts, and only a still-missing
 * config is retried.
 */
async function _createTrustAsync(job: TrustJob): Promise<boolean> {
  const maxAttempts = 3;
  for (let attempt = 1; attempt <= maxAttempts; attempt++) {
    try {
      await execa(
        'npm',
        [
          'trust',
          'github',
          job.pkg.name,
          '--file',
          job.target.file,
          '--repository',
          job.target.repository,
          '--allow-publish',
          '--yes',
          ..._registryArgs(job.registry),
        ],
        { stdio: 'inherit' }
      );
      return true;
    } catch (err) {
      OutputHelper.verbose(String(err));
    }

    await new Promise((resolve) =>
      setTimeout(resolve, TRUST_CREATE_DELAY_MS * attempt)
    );
    try {
      const status = getGithubTrustStatus(
        await _readTrustConfigsAsync(job, true),
        job.target
      );
      if (status === 'trusted') {
        return true;
      }
      if (status === 'mismatched') {
        return false;
      }
    } catch (err) {
      OutputHelper.verbose(String(err));
    }
  }
  return false;
}
