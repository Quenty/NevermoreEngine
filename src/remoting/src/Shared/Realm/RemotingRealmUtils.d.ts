import { RemotingRealm } from './RemotingRealms';

export namespace RemotingRealmUtils {
  function isRemotingRealm(value: unknown): value is RemotingRealm;
  function inferRemotingRealm(): RemotingRealm;
}
