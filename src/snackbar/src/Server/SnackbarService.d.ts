import { ServiceBag } from '@quenty/servicebag';

export interface SnackbarService {
  Init(serviceBag: ServiceBag): void;
}
