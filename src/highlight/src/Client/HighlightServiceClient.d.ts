import { ServiceBag } from '@quenty/servicebag';
import { AnimatedHighlightGroup } from './AnimatedHighlightGroup';
import { Observable } from '@quenty/rx';
import { AnimatedHighlightModel } from './Stack/AnimatedHighlightModel';

export interface HighlightServiceClient {
  readonly ServiceName: 'HighlightServiceClient';
  Init(serviceBag: ServiceBag): void;
  GetAnimatedHighlightGroup(): AnimatedHighlightGroup;
  Highlight(
    adornee: Instance,
    observeScore?: number | Observable<number>
  ): AnimatedHighlightModel;
  Destroy(): void;
}
