import { BaseObject } from '@quenty/baseobject';
import { Viewport } from './Viewport';

interface ViewportControls extends BaseObject {
  SetEnabled(enabled: boolean): void;
}

interface ViewportControlsConstructor {
  readonly ClassName: 'ViewportControls';
  new (viewport: ViewportFrame, viewportObject: Viewport): ViewportControls;
}

export const ViewportControls: ViewportControlsConstructor;
