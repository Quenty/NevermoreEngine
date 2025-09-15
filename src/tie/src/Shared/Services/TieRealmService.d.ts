import { ServiceBag } from '@quenty/servicebag';
import { TieRealm } from '../Realms/TieRealms';

export interface TieRealmService {
  Init(serviceBag: ServiceBag): void;
  SetTieRealm(tieRealm: TieRealm): void;
  GetTieRealm(): TieRealm;
}
