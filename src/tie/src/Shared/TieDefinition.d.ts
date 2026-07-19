import { Symbol } from '@quenty/symbol';
import { TieRealm, TieRealms } from './Realms/TieRealms';
import { Observable } from '@quenty/rx';
import { Brio } from '@quenty/brio';
import { Promise } from '@quenty/promise';
import { TieInterface } from './TieInterface';
import { TieImplementation } from './TieImplementation';
import { TieMemberDefinition } from './Members/TieMemberDefinition';

export type TieDefinitionMethod = Symbol;
export type TieDefinitionSignal = Symbol;
export type TieDefinitionProperty = Symbol;

interface TieDefinition<T extends Record<PropertyKey, unknown> | unknown> {
  Types: Readonly<{
    METHOD: TieDefinitionMethod;
    SIGNAL: TieDefinitionSignal;
    PROPERTY: TieDefinitionProperty;
  }>;
  Realms: typeof TieRealms;

  GetImplementations(adornee: Instance, tieRealm?: TieRealm): TieInterface[];
  GetNewImplClass(tieRealm: TieRealm): 'Configuration' | 'Camera';
  GetImplClassSet(tieRealm: TieRealm): Readonly<
    | {
        Configuration: true;
      }
    | {
        Camera: true;
      }
    | {
        Configuration: true;
        Camera: true;
      }
  >;
  GetImplementationParents(adornee: Instance, tieRealm?: TieRealm): Instance[];
  ObserveChildrenBrio(
    adornee: Instance,
    tieRealm?: TieRealm
  ): Observable<Brio<TieInterface>>;
  Promise(adornee: Instance, tieRealm?: TieRealm): Promise<TieInterface>;
  GetChildren(adornee: Instance, tieRealm?: TieRealm): TieInterface[];
  Find(adornee: Instance, tieRealm?: TieRealm): TieInterface | undefined;
  ObserveAllTaggedBrio(
    tagName: string,
    tieRealm?: TieRealm
  ): Observable<Brio<TieImplementation>>;
  FindFirstImplementation(
    adornee: Instance,
    tieRealm?: TieRealm
  ): TieInterface | undefined;
  HasImplementation(adornee: Instance, tieRealm?: TieRealm): boolean;
  ObserveIsImplemented(
    adornee: Instance,
    tieRealm?: TieRealm
  ): Observable<boolean>;
  ObserveIsImplementation(
    implParent: Instance,
    tieRealm?: TieRealm
  ): Observable<boolean>;
  ObserveIsImplementedOn(
    implParent: Instance,
    adornee: Instance,
    tieRealm?: TieRealm
  ): Observable<boolean>;
  ObserveBrio(
    adornee: Instance,
    tieRealm?: TieRealm
  ): Observable<Brio<TieImplementation>>;
  Observe(
    adornee: Instance,
    tieRealm?: TieRealm
  ): Observable<TieImplementation | undefined>;
  ObserveImplementationsBrio(
    adornee: Instance,
    tieRealm?: TieRealm
  ): Observable<Brio<TieImplementation>>;
  ObserveValidContainerChildrenBrio(
    adornee: Instance,
    tieRealm?: TieRealm
  ): Observable<Brio<Instance>>;
  Implement(
    adornee: Instance,
    implementer?: TieInterface,
    tieRealm?: TieRealm
  ): TieImplementation;
  Get(adornee: Instance, tieRealm?: TieRealm): TieInterface;
  GetName(): string;
  GetValidContainerNameSet(tieRealm?: TieRealm): Readonly<Record<string, true>>;
  GetNewContainerName(tieRealm?: TieRealm): string;
  GetMemberMap(): Readonly<Record<string, TieMemberDefinition>>;
  IsImplementation(implParent: Instance, tieRealm?: TieRealm): boolean;
}

interface TieDefinitionConstructor {
  readonly ClassName: 'TieDefinition';
  new <T extends Record<PropertyKey, unknown>>(
    definitionName: string,
    members: T
  ): TieDefinition<T>;
}

export const TieDefinition: TieDefinitionConstructor;
