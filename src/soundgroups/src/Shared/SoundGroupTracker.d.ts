import { BaseObject } from '@quenty/baseobject';
import { Brio } from '@quenty/brio';
import { Observable } from '@quenty/rx';

interface SoundGroupTracker extends BaseObject {
  GetFirstSoundGroup(soundGroupPath: string): SoundGroup | undefined;
  ObserveSoundGroup(soundGroupPath: string): Observable<SoundGroup | undefined>;
  ObserveSoundGroupBrio(soundGroupPath: string): Observable<Brio<SoundGroup>>;
  ObserveSoundGroupsBrio(): Observable<Brio<SoundGroup>>;
  ObserveSoundGroupPath(soundGroup: SoundGroup): Observable<string | undefined>;
}

interface SoundGroupTrackerConstructor {
  readonly ClassName: 'SoundGroupTracker';
  new (root?: Instance): SoundGroupTracker;
}

export const SoundGroupTracker: SoundGroupTrackerConstructor;
