import { TransitionModel } from '@quenty/transitionmodel';
import { SnackbarOptions } from '../../Shared/SnackbarOptionUtils';
import { Promise } from '@quenty/promise';

interface Snackbar extends TransitionModel {
  PromiseSustain(): Promise;
}

interface SnackbarConstructor {
  readonly ClassName: 'Snackbar';
  new (text: string, options?: SnackbarOptions): Snackbar;

  isSnackbar: (value: unknown) => value is Snackbar;
}

export const Snackbar: SnackbarConstructor;
