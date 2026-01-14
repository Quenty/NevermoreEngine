/**
 * Download roblox types command
 */

import { Argv, CommandModule } from 'yargs';
import { NevermoreGlobalArgs } from '../args/global-args.js';
import * as fs from 'fs/promises';
import * as fsSync from 'fs';
import * as https from 'https';

export interface DownloadRobloxTypesArgs extends NevermoreGlobalArgs {
  fileName?: string;
}

/**
 * Creates a new game with Nevermore dependencies
 */
export class DownloadRobloxTypes<T>
  implements CommandModule<T, DownloadRobloxTypesArgs>
{
  public command = 'download-roblox-types [file-name]';
  public describe = 'Downloads the Roblox Luau type definitions.';

  public builder(args: Argv<T>) {
    args.positional('file-name', {
      describe: 'Path to save the downloaded Roblox Luau type definitions.',
      demandOption: false,
      type: 'string',
      default: 'globalTypes.d.lua',
    });
    return args as Argv<DownloadRobloxTypesArgs>;
  }

  public async handler(args: DownloadRobloxTypesArgs) {
    await DownloadRobloxTypes._download(
      args.fileName ?? 'globalTypes.d.lua',
      'https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.lua'
    );
  }

  private static async _download(filename: string, url: string): Promise<void> {
    if (!(await DownloadRobloxTypes._needsDownload(filename))) {
      return;
    }

    return new Promise((resolve, reject) => {
      const file = fsSync.createWriteStream(filename);
      const request = https.get(url, (response: any) => {
        response.pipe(file);
        file.on('finish', () => {
          file.close();
          resolve();
        });
      });

      request.on('error', (err: Error) => {
        fsSync.unlink(filename, () => {});
        reject(err);
      });

      file.on('error', (err: Error) => {
        fsSync.unlink(filename, () => {});
        reject(err);
      });
    });
  }

  private static async _needsDownload(filename: string): Promise<boolean> {
    try {
      // Check age of file
      const stats = await fs.stat(filename);
      const oneDayInMs = 24 * 60 * 60 * 1000;
      const fileAge = Date.now() - stats.mtimeMs;

      if (fileAge > oneDayInMs) {
        return true;
      }

      return false;
    } catch (error: any) {
      // File doesn't exist
      if (error.code === 'ENOENT') {
        return true;
      }
      throw error;
    }
  }
}
