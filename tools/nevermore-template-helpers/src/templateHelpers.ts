/**
 * Helps with directory template creation
 */

import * as path from 'path';
import * as fs from 'fs';
import * as Handlebars from 'handlebars';
import * as util from 'util';
import { OutputHelper } from '@quenty/cli-output-helpers';

const existsAsync = util.promisify(fs.exists);

/**
 * Helper class for handling folder templates
 */
export class TemplateHelper {
  /**
   * Makes the string upper camel case
   */
  public static camelize(str: string): string {
    return str
      .replace(/-./g, (x) => x[1].toUpperCase())
      .replace(/(?:^\w|[A-Z]|\b\w)/g, function (word: string, index: number) {
        return word.toUpperCase();
      })
      .replace(/\s+/g, '');
  }

  /**
   * Ensures a folder exists or specifies a dryrun
   */
  public static async ensureFolderAsync(
    folderName: string,
    dryrun: boolean
  ): Promise<void> {
    if (dryrun) {
      OutputHelper.info(`[DRYRUN]: Write folder ${folderName}`);
    } else {
      await fs.promises.mkdir(folderName);
    }
  }

  /**
   * Converts a template into a directory while replacing components with different names.
   */
  public static async createDirectoryContentsAsync(
    templatePath: string,
    targetPath: string,
    input: any,
    dryrun: boolean
  ): Promise<void> {
    // read all files/folders (1 level) from template folder
    const filesToCreate = await fs.promises.readdir(templatePath);
    for (const originalName of filesToCreate) {
      const origFilePath = path.join(templatePath, originalName);

      if (originalName == 'ENSURE_FOLDER_CREATED') {
        continue;
      }

      const compiledName = (Handlebars as any).default.compile(originalName);
      let newName = compiledName(input);
      if (newName == 'gitignore') {
        newName = '.gitignore';
      }

      const stats = await fs.promises.stat(origFilePath);

      if (stats.isFile()) {
        // read file content and transform it using template engine
        const contents = await fs.promises.readFile(origFilePath, 'utf8');
        const compiled = (Handlebars as any).default.compile(contents);
        const result = compiled(input);
        const newFilePath = path.join(targetPath, newName);

        if (dryrun) {
          OutputHelper.info(`[DRYRUN]: Write file ${newFilePath}`);
          console.log(`${result}`);
        } else {
          if (!(await existsAsync(newFilePath))) {
            await fs.promises.writeFile(newFilePath, result, 'utf8');
            OutputHelper.info(`Created '${newFilePath}'`);
          } else {
            OutputHelper.error(
              `File already exists ${newFilePath} will not overwrite`
            );
          }
        }
      } else if (stats.isDirectory()) {
        const newDirPath = path.join(targetPath, originalName);
        if (dryrun) {
          OutputHelper.info(`[DRYRUN]: Write folder ${newDirPath}`);
        } else {
          // create folder in destination folder
          if (!(await existsAsync(newDirPath))) {
            await fs.promises.mkdir(newDirPath);
          }
        }

        // copy files/folder inside current folder recursively
        await TemplateHelper.createDirectoryContentsAsync(
          path.join(templatePath, originalName),
          path.join(targetPath, newName),
          input,
          dryrun
        );
      }
    }
  }
}
