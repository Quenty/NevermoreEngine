import { DuckTypeUtils } from '@quenty/ducktype';
import { BasicPane } from '@quenty/basicpane';
import { Observable } from '@quenty/rx';
import { Maid } from '@quenty/maid';

interface TransitionModel extends BasicPane {
  PromiseShow(doNotAnimate?: boolean): Promise<void>;
  promiseHide(doNotAnimate?: boolean): Promise<void>;
  promiseToggle(doNotAnimate?: boolean): Promise<void>;
  IsShowingComplete(): boolean;
  IsHidingComplete(): boolean;
  ObserveisShowingComplete(): Observable<boolean>;
  ObserveisHidingComplete(): Observable<boolean>;
  BindToPaneVisibility(pane: BasicPane): () => void;
  SetPromiseShow(
    showCallback?: (maid: Maid, doNotAnimate?: boolean) => Promise<void>
  ): void;
  SetPromiseHide(
    hideCallback?: (maid: Maid, doNotAnimate?: boolean) => Promise<void>
  ): void;
}

interface TransitionModelConstructor {
  readonly ClassName: 'TransitionModel';
  new (): TransitionModel;

  isTransitionModel: typeof DuckTypeUtils.isImplementation<TransitionModel>;
}

export const TransitionModel: TransitionModelConstructor;
