import { ServiceBag } from '@quenty/servicebag';
import { ScreenshotHudModel } from './ScreenshotHudModel';

export interface ScreenshotHudServiceClient {
  readonly ServiceName: 'ScreenshotHudServiceClient';
  Init(serviceBag: ServiceBag): void;
  PushModel(screenshotHudModel: ScreenshotHudModel): () => void;
  Destroy(): void;
}
