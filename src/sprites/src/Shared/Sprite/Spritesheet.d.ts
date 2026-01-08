import { Sprite } from './Sprite';

interface Spritesheet {
  GetPreloadAssetIds(): string;
  AddSprite(keyCode: unknown, position: Vector2, size: Vector2): Sprite;
  GetSprite(keyCode: unknown): Sprite | undefined;
  HasSprite(keyCode: unknown): boolean;
}

interface SpritesheetConstructor {
  readonly ClassName: 'Spritesheet';
  new (texture: string): Spritesheet;
}

export const Spritesheet: SpritesheetConstructor;
