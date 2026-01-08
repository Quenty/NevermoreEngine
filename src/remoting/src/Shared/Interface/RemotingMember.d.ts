import { Maid } from '@quenty/maid';
import { RemotingRealm } from '../Realm/RemotingRealms';
import { Promise } from '@quenty/promise';
import { Remoting } from './Remoting';

interface RemotingMember {
  Bind(callback: (...args: unknown[]) => unknown): Maid;
  Connect(callback: (...args: unknown[]) => void): Maid;
  DeclareEvent(): void;
  DeclareMethod(): void;
  FireServer(...args: unknown[]): void;
  InvokeServer(...args: unknown[]): unknown;
  PromiseInvokeServer(...args: unknown[]): Promise<unknown>;
  PromiseFireServer(...args: unknown[]): Promise<RemoteEvent | BindableEvent>;
  PromiseInvokeClient(player: Player, ...args: unknown[]): Promise<unknown>;
  InvokeClient(player: Player, ...args: unknown[]): void;
  FireAllClients(...args: unknown[]): void;
  FireAllClientsExcept(excludePlayer: Player, ...args: unknown[]): void;
  FireClient(player: Player, ...args: unknown[]): void;
}

interface RemotingMemberConstructor {
  readonly ClassName: 'RemotingMember';
  new (
    remoting: Remoting,
    memberName: string,
    remotingRealm: RemotingRealm
  ): RemotingMember;
}

export const RemotingMember: RemotingMemberConstructor;
