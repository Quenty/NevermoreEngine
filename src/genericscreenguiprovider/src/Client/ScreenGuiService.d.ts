import { Observable } from '@quenty/rx';
import { ServiceBag } from '@quenty/servicebag';

export interface ScreenGuiService {
  readonly ServiceName: 'ScreenGuiService';
  Init(serviceBag: ServiceBag): void;
  GetGuiParent(): Instance | undefined;
  SetGuiParent(playerGui: Instance): () => void;
  ObservePlayerGui(): Observable<Instance>;
  Destroy(): void;
}
