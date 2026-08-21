import { BasicPane } from '@quenty/basicpane';

export namespace TransitionUtils {
  function isTransition(value: unknown): value is BasicPane & {
    PromiseShow: (doNotAnimate?: boolean) => Promise<void>;
    PromiseHide: (doNotAnimate?: boolean) => Promise<void>;
    PromiseToggle: (doNotAnimate?: boolean) => Promise<void>;
  };
}
