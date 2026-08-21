import { BasicPane } from '@quenty/basicpane';

interface SoftShutdownUI extends BasicPane {
  Gui: Frame;
  SetTitle(text: string): void;
  SetSubtitle(text: string): void;
}

interface SoftShutdownUIConstructor {
  readonly ClassName: 'SoftShutdownUI';
  new (): SoftShutdownUI;
}

export const SoftShutdownUI: SoftShutdownUIConstructor;
