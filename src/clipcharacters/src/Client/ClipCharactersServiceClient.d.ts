import { ServiceBag } from '@quenty/servicebag';

export interface ClipCharactersServiceClient {
  Init(serviceBag: ServiceBag): void;
  Start(): void;
  PushDisableCharacterCollisionsWithDefault(): () => void;
  Destroy(): void;
}
