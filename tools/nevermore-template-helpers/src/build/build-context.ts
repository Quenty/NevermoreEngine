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

export interface BuildContextOptions {
  /** mkdtemp prefix (e.g. 'rojo-build-') */
  prefix?: string;
}

/**
 * Manages a build directory lifecycle for rojo builds.
 * Handles temp directory creation/cleanup and persistent build directories.
 */
export class BuildContext {
  private readonly _targetdir: string;
  private _cleaned = false;
  private readonly _trackedFiles: string[] = [];

  private constructor(dir: string) {
    this._targetdir = dir;
  }

  /**
   * Create and initialize a BuildContext. The directory is ready to use
   * when this resolves.
   */
  static async createAsync(
    options: BuildContextOptions = {}
  ): Promise<BuildContext> {
    const prefix = options.prefix ?? 'build-';
    const dir = await fs.mkdtemp(path.join(os.tmpdir(), prefix));
    return new BuildContext(dir);
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
    const { projectPath, output, plugin, pluginsFolder } = options;

    if (output && plugin) {
      throw new Error('rojoBuildAsync: specify either output or plugin, not both');
    }
    if (!output && !plugin) {
      throw new Error('rojoBuildAsync: must specify either output or plugin');
    }
    if (plugin && !pluginsFolder) {
      throw new Error('rojoBuildAsync: plugin requires pluginsFolder for cleanup tracking');
    }

    const args = ['build', projectPath];
    if (output) {
      args.push('-o', output);
    } else if (plugin) {
      args.push('--plugin', plugin);
    }

    await execa('rojo', args);

    if (plugin && pluginsFolder) {
      const pluginPath = path.join(pluginsFolder, plugin);
      this._trackedFiles.push(pluginPath);
      return pluginPath;
    }

    return undefined;
  }

  /**
   * Execute a Lune transform script with the given arguments.
   */
  async executeLuneTransformScriptAsync(scriptPath: string, ...args: string[]): Promise<void> {
    await execa('lune', ['run', scriptPath, ...args]);
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
   * Clean up the build directory and tracked files. Idempotent — safe to call multiple times.
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

    OutputHelper.verbose(`Cleaning up build directory: ${this._targetdir}`);

    try {
      await fs.rm(this._targetdir, { recursive: true, force: true });
    } catch {
      // best effort
    }
  }
}
