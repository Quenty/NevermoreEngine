import * as path from 'path';

/**
 * The `assetType` values `nevermore deploy asset upload` can send to the Open
 * Cloud Assets API. Mesh is left out on purpose: the API only accepts mesh data
 * that was itself downloaded from Roblox, which is not something a file on disk
 * can be recognized as.
 *
 * https://create.roblox.com/docs/cloud/guides/usage-assets
 */
export const ASSET_TYPES = [
  'Animation',
  'Audio',
  'Decal',
  'Image',
  'Model',
  'Video',
] as const;

export type AssetType = typeof ASSET_TYPES[number];

interface AssetFileFormat {
  /** Sent as the `fileContent` part's type; the API picks its importer from it. */
  contentType: string;
  /** Every type this extension can upload as. The first is the default. */
  assetTypes: readonly AssetType[];
}

// An image defaults to Image rather than Decal: an Image id is usable directly
// as `rbxassetid://`, where a Decal is a wrapper whose id has to be resolved to
// the image inside it before an ImageLabel can show it.
const IMAGE_TYPES = ['Image', 'Decal'] as const;

// A Roblox model file holds either, and nothing in its name says which.
const ROBLOX_MODEL_TYPES = ['Model', 'Animation'] as const;

const ASSET_FILE_FORMATS: Record<string, AssetFileFormat> = {
  '.mp3': { contentType: 'audio/mpeg', assetTypes: ['Audio'] },
  '.ogg': { contentType: 'audio/ogg', assetTypes: ['Audio'] },
  '.wav': { contentType: 'audio/wav', assetTypes: ['Audio'] },
  '.flac': { contentType: 'audio/flac', assetTypes: ['Audio'] },
  '.png': { contentType: 'image/png', assetTypes: IMAGE_TYPES },
  '.jpg': { contentType: 'image/jpeg', assetTypes: IMAGE_TYPES },
  '.jpeg': { contentType: 'image/jpeg', assetTypes: IMAGE_TYPES },
  '.bmp': { contentType: 'image/bmp', assetTypes: IMAGE_TYPES },
  '.tga': { contentType: 'image/tga', assetTypes: IMAGE_TYPES },
  '.fbx': { contentType: 'model/fbx', assetTypes: ['Model'] },
  '.gltf': { contentType: 'model/gltf+json', assetTypes: ['Model'] },
  '.glb': { contentType: 'model/gltf-binary', assetTypes: ['Model'] },
  '.rbxm': { contentType: 'model/x-rbxm', assetTypes: ROBLOX_MODEL_TYPES },
  '.rbxmx': { contentType: 'model/x-rbxm', assetTypes: ROBLOX_MODEL_TYPES },
  '.mp4': { contentType: 'video/mp4', assetTypes: ['Video'] },
  '.mov': { contentType: 'video/mov', assetTypes: ['Video'] },
};

export interface ResolvedAssetFormat {
  assetType: AssetType;
  contentType: string;
}

/**
 * Work out how a file uploads: its asset type and the content type to send.
 * The extension decides both unless `explicitType` picks one of the
 * alternatives it allows (`Decal` for an image, `Animation` for an `.rbxm`).
 */
export function resolveAssetFormat(
  filePath: string,
  explicitType?: AssetType
): ResolvedAssetFormat {
  const extension = path.extname(filePath).toLowerCase();
  const format = ASSET_FILE_FORMATS[extension];
  if (!format) {
    throw new Error(
      `Cannot upload "${filePath}": ${
        extension === '' ? 'a file with no extension' : `"${extension}"`
      } is not an asset format the Open Cloud Assets API accepts.\n` +
        `Supported: ${Object.keys(ASSET_FILE_FORMATS).join(', ')}`
    );
  }

  if (explicitType != null && !format.assetTypes.includes(explicitType)) {
    throw new Error(
      `Cannot upload "${filePath}" as ${explicitType}: ` +
        `a "${extension}" file uploads as ${format.assetTypes.join(' or ')}.`
    );
  }

  return {
    assetType: explicitType ?? format.assetTypes[0]!,
    contentType: format.contentType,
  };
}

/**
 * Whether an existing asset of this type can have its file replaced in place,
 * keeping its id. The API documents this for models only, and marks images,
 * audio and video "not available for updating" — so a changed image or sound
 * is always a new asset with a new id.
 */
export function canUpdateAssetContent(assetType: AssetType): boolean {
  return assetType === 'Model';
}
