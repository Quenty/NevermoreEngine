export type GameConfigAssetType =
  (typeof GameConfigAssetTypes)[keyof typeof GameConfigAssetTypes];

export const GameConfigAssetTypes: Readonly<{
  BADGE: 'badge';
  PRODUCT: 'product';
  PASS: 'pass';
  ASSET: 'asset';
  BUNDLE: 'bundle';
  PLACE: 'place';
  SUBSCRIPTION: 'subscription';
  MEMBERSHIP: 'membership';
}>;
