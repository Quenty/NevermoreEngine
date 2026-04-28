import { TieRealm } from '../../Realms/TieRealms';
import { TieDefinition } from '../../TieDefinition';
import { TieMemberDefinition } from '../TieMemberDefinition';

interface TieMethodDefinition extends TieMemberDefinition {}

interface TieMethodDefinitionConstructor {
  readonly ClassName: 'TieMethodDefinition';
  new (
    tieDefinition: TieDefinition<unknown>,
    methodName: string,
    memberTieRealm: TieRealm
  ): TieMethodDefinition;
}

export const TieMethodDefinition: TieMethodDefinitionConstructor;
