import { BaseObject } from '@quenty/baseobject';
import { Promise } from '@quenty/promise';
import { Observable } from '@quenty/rx';

interface AvatarEditorInventory extends BaseObject {
  PromiseProcessPages(inventoryPages: InventoryPages): Promise;
  IsAssetIdInInventory(assetId: number): boolean;
  ObserveAssetIdInInventory(assetId: number): Observable<{
    AssetId: number;
    AssetType: string;
    Created: string;
    Name: string;
  }>;
}

interface AvatarEditorInventoryConstructor {
  readonly ClassName: 'AvatarEditorInventory';
  new (): AvatarEditorInventory;
}

export const AvatarEditorInventory: AvatarEditorInventoryConstructor;
