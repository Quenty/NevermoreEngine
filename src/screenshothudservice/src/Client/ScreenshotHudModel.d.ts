import { BaseObject } from '@quenty/baseobject';
import { Observable } from '@quenty/rx';
import { Signal } from '@quenty/signal';

interface ScreenshotHudModel extends BaseObject {
  CloseRequested: Signal;
  SetCloseButtonVisible(closeButtonVisible: boolean): void;
  ObserveCloseButtonVisible(): Observable<boolean>;
  SetCameraButtonVisible(cameraButtonVisible: boolean): void;
  ObserveCameraButtonVisible(): Observable<boolean>;
  SetKeepOpen(keepOpen: boolean): void;
  GetKeepOpen(): boolean;
  SetVisible(visible: boolean): void;
  SetCloseButtonPosition(position: UDim2 | undefined): void;
  ObserveCloseButtonPosition(): Observable<UDim2 | undefined>;
  SetCameraButtonPosition(position: UDim2 | undefined): void;
  ObserveCameraButtonPosition(): Observable<UDim2 | undefined>;
  SetOverlayFont(overlayFont: Enum.Font | undefined): void;
  ObserveOverlayFont(): Observable<Enum.Font>;
  SetCameraButtonIcon(icon: string | undefined): void;
  ObserveCameraButtonIcon(): Observable<string>;
  SetCloseWhenScreenshotTaken(closeWhenScreenshotTaken: boolean): void;
  GetCloseWhenScreenshotTaken(): boolean;
  ObserveCloseWhenScreenshotTaken(): Observable<boolean>;
  SetExperienceNameOverlayEnabled(experienceNameOverlayEnabled: boolean): void;
  ObserveExperienceNameOverlayEnabled(): Observable<boolean>;
  SetUsernameOverlayEnabled(usernameOverlayEnabled: boolean): void;
  ObserveUsernameOverlayEnabled(): Observable<boolean>;
  ObserveVisible(): Observable<boolean>;
  InternalNotifyVisible(isVisible: boolean): void;
  InternalFireClosedRequested(): void;
}

interface ScreenshotHudModelConstructor {
  readonly ClassName: 'ScreenshotHudModel';
  new (): ScreenshotHudModel;
}

export const ScreenshotHudModel: ScreenshotHudModelConstructor;
