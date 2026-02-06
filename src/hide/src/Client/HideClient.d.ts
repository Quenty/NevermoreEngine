import { Binder } from '@quenty/binder';

interface HideClient {
  Destroy(): void;
}

interface HideClientConstructor {
  readonly ClassName: 'HideClient';
  new (adornee: Instance): HideClient;
}

export const HideClient: Binder<HideClient>;
