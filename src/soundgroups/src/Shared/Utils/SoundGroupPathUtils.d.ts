export namespace SoundGroupPathUtils {
  function isSoundGroupPath(soundGroupPath: unknown): soundGroupPath is string;
  function toPathTable(soundGroupPath: string): string[];
  function findSoundGroup(
    soundGroupPath: string,
    root?: Instance
  ): SoundGroup | undefined;
  function findOrCreateSoundGroup(
    soundGroupPath: string,
    root?: Instance
  ): SoundGroup;
}
