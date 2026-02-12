export type CallToActionOptions = {
  Text: string;
  OnClick?: () => void;
};

export type SnackbarOptions = {
  CallToAction?: string | CallToActionOptions;
};

export namespace SnackbarOptionUtils {
  function createSnackbarOptions(options: SnackbarOptions): SnackbarOptions;
  function isSnackbarOptions(value: unknown): value is SnackbarOptions;
}
