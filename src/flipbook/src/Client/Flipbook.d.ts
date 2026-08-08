import { Sprite } from '@quenty/sprites';

export interface FlipbookData {
  image: string;
  frameCount: number;
  rows: number;
  columns: number;
  imageRectSize: Vector2;
  frameRate?: number;
  restFrame?: number;
}

interface Flipbook {
  GetRestFrame(): number | undefined;
  SetSpriteAtIndex(index: number, sprite: Sprite): void;
  SetImageRectSize(imageRectSize: Vector2): void;
  SetFrameCount(frameCount: number): void;
  SetFrameRate(frameRate: number): void;
  GetPreloadAssetId(): string[];
  GetSprite(index: number): Sprite | undefined;
  HasSprite(index: number): boolean;
  GetImageRectSize(): Vector2;
  GetFrameRate(): number;
  GetPlayTime(): number;
  GetFrameCount(): number;
}

interface FlipbookConstructor {
  readonly ClassName: 'Flipbook';
  new (data: FlipbookData): Flipbook;

  isFlipbook: (value: unknown) => value is Flipbook;
}

export const Flipbook: FlipbookConstructor;
