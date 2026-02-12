import { BaseObject } from '@quenty/baseobject';
import { Flipbook } from '../Flipbook';
import { Promise } from '@quenty/promise';
import { Observable } from '@quenty/rx';

interface FlipbookPlayer extends BaseObject {
  SetFlipbook(flipbook: Flipbook): void;
  GetFlipbook(): Flipbook | undefined;
  PromisePlayOnce(): Promise;
  PromisePlayRepeat(times: number): Promise;
  SetIsBoomarang(isBoomerang: boolean): void;
  Play(): void;
  Stop(): void;
  IsPlaying(): boolean;
  ObserveIsPlaying(): Observable<boolean>;
}

interface FlipbookPlayerConstructor {
  readonly ClassName: 'FlipbookPlayer';
  new (imageLabel: ImageLabel | ImageButton): FlipbookPlayer;
}

export const FlipbookPlayer: FlipbookPlayerConstructor;
