import { TieRealm } from './TieRealms';

export namespace TieRealmUtils {
  function isTieRealm(value: unknown): value is TieRealm;
  function inferTieRealm(): 'client' | 'server';
}
