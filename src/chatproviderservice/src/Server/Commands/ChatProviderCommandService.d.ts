import { ServiceBag } from '@quenty/servicebag';

export interface ChatProviderCommandService {
  readonly ServiceName: 'ChatProviderCommandService';
  Init(serviceBag: ServiceBag): void;
  Start(): void;
  GetChatTagKeyList(): string[];
  Destroy(): void;
}
