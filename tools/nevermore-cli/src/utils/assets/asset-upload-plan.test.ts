import { describe, it, expect } from 'vitest';
import { buildAssetUploadPlan } from './asset-upload-plan.js';

describe('buildAssetUploadPlan', () => {
  it('names each asset after its file, and describes it by its name', () => {
    expect(
      buildAssetUploadPlan({ files: ['art/icons_1.png', 'models/City.fbx'] })
    ).toEqual([
      {
        filePath: 'art/icons_1.png',
        assetType: 'Image',
        contentType: 'image/png',
        displayName: 'icons_1',
        description: 'icons_1',
        assetId: undefined,
      },
      {
        filePath: 'models/City.fbx',
        assetType: 'Model',
        contentType: 'model/fbx',
        displayName: 'City',
        description: 'City',
        assetId: undefined,
      },
    ]);
  });

  it('takes an explicit name and description for a single file', () => {
    const [entry] = buildAssetUploadPlan({
      files: ['City.fbx'],
      name: 'Openfront City',
      description: 'Unit model',
    });

    expect(entry?.displayName).toBe('Openfront City');
    expect(entry?.description).toBe('Unit model');
  });

  it('refuses one name for several files', () => {
    expect(() =>
      buildAssetUploadPlan({ files: ['a.png', 'b.png'], name: 'Icon' })
    ).toThrowError(/--name names one asset, but 2 files were given/);
  });

  it('plans a replacement when given the id of an existing model', () => {
    const [entry] = buildAssetUploadPlan({
      files: ['City.fbx'],
      assetId: 123,
    });

    expect(entry?.assetId).toBe(123);
  });

  it('refuses to replace anything but a model', () => {
    // The API has no in-place update for these, so letting the request through
    // would only trade a clear message for whatever the server says instead.
    expect(() =>
      buildAssetUploadPlan({ files: ['icon.png'], assetId: 123 })
    ).toThrowError(/only replaces the content of a Model/);
  });

  it('refuses one asset id for several files', () => {
    expect(() =>
      buildAssetUploadPlan({ files: ['a.fbx', 'b.fbx'], assetId: 123 })
    ).toThrowError(/--asset-id replaces one asset, but 2 files were given/);
  });

  it('rejects the whole batch when one file cannot be uploaded', () => {
    // Nothing is uploaded until every file is known to be uploadable: a batch
    // that fails partway has already created assets that cannot be taken back.
    expect(() =>
      buildAssetUploadPlan({ files: ['a.png', 'notes.txt'] })
    ).toThrowError(/"\.txt" is not an asset format/);
  });
});
