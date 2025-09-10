interface SoundOptions {
  SoundId: number | string;
}

type SoundIdLike = string | number | SoundOptions;

export namespace SoundUtils {
  function playFromId(id: SoundIdLike): Sound;
  function createSoundFromId(id: SoundIdLike): Sound;
  function applyPropertiesFromId(sound: Sound, id: SoundIdLike): void;
  function playFromIdInParent(i: SoundIdLike, parent: Instance): Sound;
  function removeAfterTimeLength(sound: Sound): void;
  function playTemplate(
    templates: TemplateProvider,
    templateName: string
  ): Sound;
  function toRbxAssetId(id: SoundIdLike): string;
  function isConvertableToRbxAsset(soundId: SoundIdLike): boolean;
  function playTemplateInParent(
    templates: TemplateProvider,
    templateName: string,
    parent: Instance
  ): Sound;
}
