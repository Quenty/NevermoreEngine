import { ServiceBag } from '@quenty/servicebag';
import { AssetServiceUtils } from './AssetServiceUtils';

export interface AssetServiceCache {
  Init(serviceBag: ServiceBag): void;
  PromiseBundleDetails(
    bundleId: number
  ): ReturnType<typeof AssetServiceUtils.promiseBundleDetails>;
}
