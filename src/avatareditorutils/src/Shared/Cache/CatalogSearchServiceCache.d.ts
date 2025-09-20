import { Promise } from '@quenty/promise';
import { ServiceBag } from '@quenty/servicebag';
import { ToItemDetails } from '../AvatarEditorUtils';
import { PagesProxy } from '@quenty/pagesutils';

export interface CatalogSearchServiceCache {
  Init(serviceBag: ServiceBag): void;
  PromiseAvatarRules(): Promise<AvatarRules>;
  PromiseItemDetails<T extends Enum.AvatarItemType>(
    assetId: number,
    avatarItemType: T
  ): Promise<ToItemDetails<T>[]>;
  PromiseSearchCatalog(
    params: CatalogSearchParams
  ): Promise<PagesProxy<CatalogPages>>;
}
