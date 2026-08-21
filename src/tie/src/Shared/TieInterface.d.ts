import { Observable } from '@quenty/rx';
import { TieRealm } from './Realms/TieRealms';
import { TieDefinition } from './TieDefinition';

interface TieInterface {
  IsImplemented(): boolean;
  GetTieAdornee(): Instance | undefined;
  ObserveIsImplemented(): Observable<boolean>;
}

interface TieInterfaceConstructor {
  readonly ClassName: 'TieInterface';
  new (
    definition: TieDefinition<unknown>,
    implParent: Instance | undefined,
    adornee: Instance | undefined,
    interfaceTieRealm: TieRealm
  ): TieInterface;
}

export const TieInterface: TieInterfaceConstructor;
