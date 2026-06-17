import { Maid } from '@quenty/maid';
import { Observable } from '@quenty/rx';

export interface EnabledMixin {
  InitEnabledMixin(maid?: Maid): void;
  IsEnabled(): boolean;
  Enable(doNotAnimate?: boolean): void;
  Disable(doNotAnimate?: boolean): void;
  ObserveIsEnabled(): Observable<boolean>;
  SetEnabled(isEnabled: boolean, doNotAnimate?: boolean): void;
}

export const EnabledMixin: {
  Add(classObj: { new (...args: unknown[]): unknown }): void;
};
