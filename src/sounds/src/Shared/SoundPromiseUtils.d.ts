import { Promise } from '@quenty/promise';

export namespace SoundPromiseUtils {
  function promiseLoaded(sound: Sound): Promise;
  function promisePlayed(sound: Sound): Promise;
  function promiseLooped(sound: Sound): Promise;
  function promiseAllSoundsLoaded(sounds: Sound[]): Promise;
}
