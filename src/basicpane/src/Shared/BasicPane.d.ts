import { Brio } from '@quenty/brio';
import { Observable } from '@quenty/rx';

interface BasicPane {
  SetVisible(isVisible: boolean, doNotAnimate?: boolean): void;
  ObserveVisible(): Observable<boolean>;
  ObserveVisibleBrio(): Observable<Brio<boolean>>;
  Show(doNotAnimate?: boolean): void;
  Hide(doNotAnimate?: boolean): void;
  Toggle(doNotAnimate?: boolean): void;
  IsVisible(): boolean;
  Destroy(): void;
}

interface BasicPaneConstructor {
  readonly ClassName: 'BasicPane';
  new (gui?: GuiObject): BasicPane;

  isBasicPane: (value: unknown) => value is BasicPane;
}

export const BasicPane: BasicPaneConstructor;
