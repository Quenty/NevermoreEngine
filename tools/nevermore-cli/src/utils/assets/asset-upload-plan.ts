import * as path from 'path';
import {
  canUpdateAssetContent,
  resolveAssetFormat,
  type AssetType,
} from './asset-formats.js';

export interface AssetUploadPlanOptions {
  files: string[];
  /** Applied to every file; each must be able to upload as it. */
  type?: AssetType;
  /** Display name. Single file only — defaults to the file's base name. */
  name?: string;
  description?: string;
  /** Replace this asset's content instead of creating one. Single file only. */
  assetId?: number;
}

export interface AssetUploadPlanEntry {
  filePath: string;
  assetType: AssetType;
  contentType: string;
  displayName: string;
  description: string;
  /** Set when the upload replaces an existing asset's content in place. */
  assetId?: number;
}

/**
 * Turn the command line into one upload per file, rejecting anything that
 * could not work before a single request is sent — a batch that fails on its
 * fifth file has already created four assets.
 */
export function buildAssetUploadPlan(
  options: AssetUploadPlanOptions
): AssetUploadPlanEntry[] {
  const { files, type, name, description, assetId } = options;

  if (files.length === 0) {
    throw new Error('No files to upload.');
  }
  if (files.length > 1 && name != null) {
    throw new Error(
      `--name names one asset, but ${files.length} files were given. ` +
        `Drop it to name each asset after its file.`
    );
  }
  if (files.length > 1 && assetId != null) {
    throw new Error(
      `--asset-id replaces one asset, but ${files.length} files were given.`
    );
  }
  if (assetId != null && (!Number.isSafeInteger(assetId) || assetId < 1)) {
    throw new Error('--asset-id must be a positive integer.');
  }

  return files.map((filePath) => {
    const { assetType, contentType } = resolveAssetFormat(filePath, type);
    if (assetId != null && !canUpdateAssetContent(assetType)) {
      throw new Error(
        `Cannot replace asset ${assetId} with "${filePath}": the Assets API ` +
          `only replaces the content of a Model. Upload the ${assetType} ` +
          `without --asset-id to create a new asset instead.`
      );
    }

    const displayName = name ?? path.basename(filePath, path.extname(filePath));
    return {
      filePath,
      assetType,
      contentType,
      displayName,
      // The API requires a description on create, so an omitted one falls back
      // to the name rather than to text nobody chose.
      description: description ?? displayName,
      assetId,
    };
  });
}
