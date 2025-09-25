import { ServiceBag } from '@quenty/servicebag';

export interface ClipCharactersServiceClient {
  readonly ServiceName: 'ClipCharactersServiceClient';
  Init(serviceBag: ServiceBag): void;
  Start(): void;
  PushDisableCharacterCollisionsWithDefault(): () => void;
  Destroy(): void;
}
