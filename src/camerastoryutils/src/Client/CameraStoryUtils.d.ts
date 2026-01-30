import { Maid } from '@quenty/maid';
import { Promise } from '@quenty/promise';

export namespace CameraStoryUtils {
  function reflectCamera(maid: Maid, topCamera: Camera): Camera;
  function setupViewportFrame(maid: Maid, target: GuiBase): ViewportFrame;
  function promiseCrate(
    maid: Maid,
    viewportFrame: ViewportFrame,
    properties: Partial<WritableInstanceProperties<BasePart>>
  ): Promise<Instance>;
  function getInterpolationFactory(
    maid: Maid,
    viewportFrame: ViewportFrame,
    low: number,
    high: number,
    period: number,
    toCFrame: (cframe: CFrame) => CFrame
  ): (
    interpolate: (t: number) => CFrame,
    color: Color3,
    label?: string,
    labelOffset?: Vector2
  ) => void;
}
