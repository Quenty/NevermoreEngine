import { ServiceBag } from '@quenty/servicebag';
import { SnackbarOptions } from '../Shared/SnackbarOptionUtils';
import { Snackbar } from './Gui/Snackbar';

export interface SnackbarServiceClient {
  readonly ClassName: 'SnackbarServiceClient';
  Init(serviceBag: ServiceBag): void;
  SetScreenGui(screenGui: ScreenGui): void;
  ShowSnackbar(
    text: string,
    options?: {
      options?: SnackbarOptions;
    }
  ): Snackbar;
  HideCurrent(doNotAnimate?: boolean): void;
  ClearQueue(doNotAnimate?: boolean): void;
  Destroy(): void;
}
