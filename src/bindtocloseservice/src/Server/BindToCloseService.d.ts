import { Promise } from '@quenty/promise';
import { ServiceBag } from '@quenty/servicebag';

export interface BindToCloseService {
  Init(serviceBag: ServiceBag): void;
  Start(): void;
  RegisterPromiseOnCloseCallback(saveCallback: () => Promise): () => void;
  Destroy(): void;
}
