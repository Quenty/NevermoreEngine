import { BaseObject } from '@quenty/baseobject';
import { TieRealm } from '../Realms/TieRealms';
import { TieDefinition } from '../TieDefinition';

interface TieMemberDefinition extends BaseObject {
  Implement<T>(
    implParent: Instance,
    initialValue: (actualSelf: T, ...args: unknown[]) => unknown,
    actualSelf: T,
    tieRealm: TieRealm
  ): void;
  GetInterface(
    implParent: Instance,
    aliasSelf: unknown,
    tieRealm: TieRealm
  ): void;
  GetFriendlyName(): string;
  IsRequiredForInterface(currentRealm: TieRealm): boolean;
  IsAllowedOnInterface(currentRealm: TieRealm): boolean;
  IsRequiredForImplementation(currentRealm: TieRealm): boolean;
  IsAllowedForImplementation(currentRealm: TieRealm): boolean;
  GetMemberTieRealm(): TieRealm;
  GetTieDefinition(): TieDefinition<unknown>;
  GetMemberName(): string;
}

interface TieMemberDefinitionConstructor {
  readonly ClassName: 'TieMemberDefinition';
  new (
    tieDefinition: TieDefinition<unknown>,
    memberName: string,
    memberTieRealm: TieRealm
  ): TieMemberDefinition;
}

export const TieMemberDefinition: TieMemberDefinitionConstructor;
