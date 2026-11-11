import { describe, it, expect } from 'vitest';
import { canUpdateAssetContent, resolveAssetFormat } from './asset-formats.js';

describe('resolveAssetFormat', () => {
  it('reads the asset type and content type off the extension', () => {
    expect(resolveAssetFormat('models/City.fbx')).toEqual({
      assetType: 'Model',
      contentType: 'model/fbx',
    });
    expect(resolveAssetFormat('sfx/click.ogg')).toEqual({
      assetType: 'Audio',
      contentType: 'audio/ogg',
    });
  });

  it('ignores the case of the extension', () => {
    expect(resolveAssetFormat('ICON.PNG').contentType).toBe('image/png');
  });

  it('uploads an image as an Image unless told Decal', () => {
    expect(resolveAssetFormat('icon.png').assetType).toBe('Image');
    expect(resolveAssetFormat('icon.png', 'Decal')).toEqual({
      assetType: 'Decal',
      contentType: 'image/png',
    });
  });

  it('uploads an .rbxm as a Model unless told Animation', () => {
    expect(resolveAssetFormat('rig.rbxm').assetType).toBe('Model');
    expect(resolveAssetFormat('walk.rbxm', 'Animation').assetType).toBe(
      'Animation'
    );
  });

  it('refuses a type the extension cannot upload as', () => {
    expect(() => resolveAssetFormat('icon.png', 'Audio')).toThrowError(
      /a "\.png" file uploads as Image or Decal/
    );
  });

  it('refuses an extension the API does not accept, naming the ones it does', () => {
    expect(() => resolveAssetFormat('notes.txt')).toThrowError(
      /"\.txt" is not an asset format[\s\S]*\.fbx/
    );
    expect(() => resolveAssetFormat('README')).toThrowError(
      /a file with no extension/
    );
  });
});

describe('canUpdateAssetContent', () => {
  it('is only true for models', () => {
    expect(canUpdateAssetContent('Model')).toBe(true);
    expect(canUpdateAssetContent('Image')).toBe(false);
    expect(canUpdateAssetContent('Audio')).toBe(false);
  });
});
