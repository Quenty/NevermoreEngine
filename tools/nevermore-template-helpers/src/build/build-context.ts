import { OutputHelper } from '@quenty/cli-output-helpers';
import { execa } from 'execa';
import * as fs from 'fs/promises';
import * as os from 'os';
import * as path from 'path';

export interface RojoBuildOptions {
  /** Absolute path to the rojo project JSON file */
  projectPath: string;
  /** -o flag: absolute path to output file (.rbxl / .rbxm) */
  output?: string;
  /** --plugin flag: filename placed in Studio's plugins folder */
  plugin?: string;
  /** Absolute path to Studio's plugins folder (required when plugin is set) */
  pluginsFolder?: string;
}

/**
 * Single call site for all rojo build invocations across the codebase.
 * Exactly one of `output` or `plugin` must be provided.
 */
export async function rojoBuildAsync(options: RojoBuildOptions): Promise<void> {
  const { projectPath, output, plugin } = options;

  if (output && plugin) {
    throw new Error('rojoBuildAsync: specify either output or plugin, not both');
  }
  if (!output && !plugin) {
    throw new Error('rojoBuildAsync: must specify either output or plugin');
  }

  const args = ['build', projectPath];

  if (output) {
    args.push('-o', output);
  } else if (plugin) {
    args.push('--plugin', plugin);
  }

  await execa('rojo', args);
}

export interface BuildContextOptions {
  /** 'temp' creates a disposable mkdtemp directory; 'persistent' uses an existing path */
  mode: 'temp' | 'persistent';
  /** temp mode: mkdtemp prefix (e.g. 'studio-bridge-') */
  prefix?: string;
  /** persistent mode: absolute path to build dir */
  buildDir?: string;
}

/**
 * Manages a build directory lifecycle for rojo builds.
 * Handles temp directory creation/cleanup and persistent build directories.
 */
export class BuildContext {
  private readonly _targetdir: string;
  private _cleaned = false;
  private readonly _mode: 'temp' | 'persistent';
  private readonly _trackedFiles: string[] = [];

  private constructor(dir: string, mode: 'temp' | 'persistent') {
    this._targetdir = dir;
    this._mode = mode;
  }

  /**
   * Create and initialize a BuildContext. The directory is ready to use
   * when this resolves.
   */
  static async createAsync(
    options: BuildContextOptions
  ): Promise<BuildContext> {
    let dir: string;

    if (options.mode === 'temp') {
      const prefix = options.prefix ?? 'build-';
      dir = await fs.mkdtemp(path.join(os.tmpdir(), prefix));
    } else {
      if (!options.buildDir) {
        throw new Error('BuildContext: persistent mode requires buildDir');
      }
      dir = options.buildDir;
      await fs.mkdir(dir, { recursive: true });
    }

    return new BuildContext(dir, options.mode);
  }

  /** Absolute path to the managed build directory. */
  get buildDir(): string {
    return this._targetdir;
  }

  /** Resolve a relative path within the build directory. */
  resolvePath(relativePath: string): string {
    return path.join(this._targetdir, relativePath);
  }

  /**
   * Run rojo build using this context's directory.
   * Returns the full plugin output path when in plugin mode, undefined otherwise.
   */
  async rojoBuildAsync(options: RojoBuildOptions): Promise<string | undefined> {
    if (options.plugin && !options.pluginsFolder) {
      throw new Error('rojoBuildAsync: plugin requires pluginsFolder for cleanup tracking');
    }

    await rojoBuildAsync(options);

    if (options.plugin && options.pluginsFolder) {
      const pluginPath = path.join(options.pluginsFolder, options.plugin);
      this._trackedFiles.push(pluginPath);
      return pluginPath;
    }

    return undefined;
  }

  /**
   * Write a file into the build directory.
   * @returns Absolute path to the written file.
   */
  async writeFileAsync(relativePath: string, content: string): Promise<string> {
    const fullPath = path.join(this._targetdir, relativePath);
    await fs.mkdir(path.dirname(fullPath), { recursive: true });
    await fs.writeFile(fullPath, content, 'utf-8');
    return fullPath;
  }

  /**
   * Clean up the build directory. Idempotent — safe to call multiple times.
   * Only removes temp directories; persistent directories are left intact.
   */
  async cleanupAsync(): Promise<void> {
    if (this._cleaned) return;
    this._cleaned = true;

    for (const filePath of this._trackedFiles) {
      try {
        await fs.unlink(filePath);
      } catch {
        // best effort — file may already be gone
      }
    }

    if (this._mode === 'temp') {
      OutputHelper.verbose(`Cleaning up build directory: ${this._targetdir}`);

      try {
        await fs.rm(this._targetdir, { recursive: true, force: true });
      } catch {
        // best effort
      }
    }
  }
}
