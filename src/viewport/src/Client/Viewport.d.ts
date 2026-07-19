import { BasicPane } from '@quenty/basicpane';
import { Observable } from '@quenty/rx';

interface Viewport extends BasicPane {
  ObserveTransparency(): Observable<number>;
  SetControlsEnabled(enabled: boolean): void;
  SetTransparency(transparency: number | undefined): void;
  SetFieldOfView(fieldOfView: number | undefined): void;
  SetInstance(instance: Instance | undefined): void;
  NotifyInstanceSizeChanged(): void;
  SetYaw(yaw: number, doNotAnimate?: boolean): void;
  SetPitch(pitch: number, doNotAnimate?: boolean): void;
  RotateBy(deltaV2: Vector2, doNotAnimate?: boolean): void;
  Render(
    props: Partial<WritableInstanceProperties<ViewportFrame>>
  ): Observable<ViewportFrame>;
}

interface ViewportConstructor {
  readonly ClassName: 'Viewport';
  new (): Viewport;

  blend: (
    props: Partial<WritableInstanceProperties<ViewportFrame>>
  ) => Observable<ViewportFrame>;
}

export const Viewport: ViewportConstructor;
