import { ServiceBag } from '@quenty/servicebag';

export interface ChatProviderCommandServiceClient {
  readonly ServiceName: 'ChatProviderCommandServiceClient';
  Init(serviceBag: ServiceBag): void;
  Start(): void;
  GetChatTagKeyList(): string[];
}
