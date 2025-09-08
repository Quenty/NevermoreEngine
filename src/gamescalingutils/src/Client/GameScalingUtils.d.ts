import { Observable } from '@quenty/rx';

export namespace GameScalingUtils {
  function getUIScale(screenAbsoluteSize: Vector2): number;
  function observeUIScale(screenGui: ScreenGui): Observable<number>;
  function observeUIScaleForChild(child: Instance): Observable<number>;
  function renderUIScale(props: {
    [key: string]: unknown;
  }): Observable<UIScale>;
  function renderDialogPadding(props: {
    [key: string]: unknown;
  }): Observable<UIPadding>;
  function observeDialogPadding(screenGui: ScreenGui): Observable<UDim>;
  function getDialogPadding(screenAbsoluteSize: Vector2): number;
}
