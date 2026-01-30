import { Sprite } from '../Sprite/Sprite';
import { Spritesheet } from '../Sprite/Spritesheet';

interface InputImageLibrary {
  GetPreloadAssetIds(): string[];
  GetSprite(
    keyCode: unknown,
    preferredStyle?: string,
    preferredPlatform?: string
  ): Sprite | undefined;
  StyleImage<T extends ImageLabel | ImageButton>(
    gui: T,
    keyCode: unknown,
    preferredStyle?: string,
    preferredPlatform?: string
  ): T | undefined;
  GetScaledImageLabel(
    keyCode: unknown,
    preferredStyle?: string,
    preferredPlatform?: string
  ):
    | (ImageLabel & {
        UIAspectRatioConstraint: UIAspectRatioConstraint;
      })
    | undefined;
  PickSheet(
    keyCode: unknown,
    preferredStyle?: string,
    preferredPlatform?: string
  ): Spritesheet;
}

interface InputImageLibraryConstructor {
  readonly ClassName: 'InputImageLibrary';
  new (parentFolder: Folder): InputImageLibrary;
}

export const InputImageLibrary: InputImageLibrary;
