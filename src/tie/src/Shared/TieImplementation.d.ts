import { TieRealm } from './Realms/TieRealms';
import { TieDefinition } from './TieDefinition';
import { TieInterface } from './TieInterface';
import { BaseObject } from '@quenty/baseobject';

interface TieImplementation extends BaseObject {
  GetImplementationTieRealm(): TieRealm;
  GetImplParent(): Instance;
}

interface TieImplementationConstructor {
  readonly ClassName: 'TieImplementation';
  new (
    tieDefinition: TieDefinition<unknown>,
    adornee: Instance,
    implementer: TieInterface,
    implementationTieRealms: TieRealm
  ): TieImplementation;
}

export const TieImplementation: TieImplementationConstructor;
