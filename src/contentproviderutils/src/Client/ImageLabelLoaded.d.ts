import { BaseObject } from '@quenty/baseobject';
import { Promise } from '@quenty/promise';
import { Signal } from '@quenty/signal';

interface ImageLabelLoaded extends BaseObject {
  ImageChanged: Signal;

  SetDefaultTimeout(defaultTimeout?: number): void;
  SetPreloadImage(preloadImage: boolean): void;
  PromiseLoaded(timeout?: number): Promise;
  SetImageLabel(imageLabel?: ImageLabel): void;
}

interface ImageLabelLoadedConstructor {
  readonly ClassName: 'ImageLabelLoaded';
  new (): ImageLabelLoaded;
}

export const ImageLabelLoaded: ImageLabelLoadedConstructor;
