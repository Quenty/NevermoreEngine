import { Binder } from '@quenty/binder';

interface Hide {
  Destroy(): void;
}

interface HideConstructor {
  readonly ClassName: 'Hide';
  new (adornee: Instance): Hide;
}

export const Hide: Binder<Hide>;
