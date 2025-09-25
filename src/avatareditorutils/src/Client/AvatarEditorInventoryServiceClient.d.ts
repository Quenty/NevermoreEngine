import { Promise } from '@quenty/promise';
import { Observable } from '@quenty/rx';
import { ServiceBag } from '@quenty/servicebag';

export interface AvatarEditorInventoryServiceClient {
  readonly ServiceName: 'AvatarEditorInventoryServiceClient';
  Init(serviceBag: ServiceBag): void;
  PromiseInventoryPages(
    avatarAssetType: Enum.AvatarAssetType
  ): Promise<InventoryPages>;
  PromiseInventoryForAvatarAssetType(
    avatarAssetType: Enum.AvatarAssetType
  ): Promise<InventoryPages>;
  IsInventoryAccessAllowed(): boolean;
  ObserveIsInventoryAccessAllowed(): Observable<boolean>;
  PromiseEnsureAccess(): Promise<boolean>;
  Destroy(): void;
}
