interface PlayerAssetOwnershipTracker {
  SetParent(parent?: Instance): void;
  Show(): void;
  Set(a: Vector2, b: Vector2, c: Vector2): this;
  Hide(): void;
  SetA(a: Vector2): this;
  SetB(b: Vector2): this;
  SetC(c: Vector2): this;
  UpdateRender(): void;
  Destroy(): void;
}

interface PlayerAssetOwnershipTrackerConstructor {
  readonly ClassName: 'PlayerAssetOwnershipTracker';
  new (parent?: Instance): PlayerAssetOwnershipTracker;

  ExtraPixels: 2;
}

export const PlayerAssetOwnershipTracker: PlayerAssetOwnershipTrackerConstructor;
