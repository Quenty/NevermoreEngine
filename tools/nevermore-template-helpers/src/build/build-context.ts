import * as fs from 'fs/promises';
import * as os from 'os';
import * as path from 'path';

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
  readonly dir: string;
  private _cleaned = false;
  private readonly _mode: 'temp' | 'persistent';

  private constructor(dir: string, mode: 'temp' | 'persistent') {
    this.dir = dir;
    this._mode = mode;
  }

  /**
   * Create and initialize a BuildContext. The directory is ready to use
   * when this resolves.
   */
  static async createAsync(options: BuildContextOptions): Promise<BuildContext> {
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

  /**
   * Write a file into the build directory.
   * @returns Absolute path to the written file.
   */
  async writeFileAsync(relativePath: string, content: string): Promise<string> {
    const fullPath = path.join(this.dir, relativePath);
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

    if (this._mode === 'temp') {
      try {
        await fs.rm(this.dir, { recursive: true, force: true });
      } catch {
        // best effort
      }
    }
  }
}
