export interface SpriteData {
  Texture: string;
  Size: Vector2;
  Position: Vector2;
  Name: string;
}

interface Sprite {
  Style<T extends ImageLabel | ImageButton>(gui: T): T;
  Get<T extends 'ImageLabel' | 'ImageButton'>(gui: T): Instances[T];
}

interface SpriteConstructor {
  readonly ClassName: 'Sprite';
  new (data: SpriteData): Sprite;
}

export const Sprite: SpriteConstructor;
