import { Maid } from '@quenty/maid';
import { RemotingRealm } from '../Realm/RemotingRealms';
import { RemotingMember } from './RemotingMember';

type Remoting = {
  Connect(memberName: string, callback: (...args: unknown[]) => void): Maid;
  Bind(memberName: string, callback: (...args: unknown[]) => unknown): Maid;
  DeclareEvent(memberName: string): void;
  DeclareMethod(memberName: string): void;
  FireClient(memberName: string, player: Player, ...args: unknown[]): void;
  InvokeClient(memberName: string, player: Player, ...args: unknown[]): unknown;
  FireAllClients(memberName: string, ...args: unknown[]): void;
  FireAllClientsExcept(
    memberName: string,
    excludePlayer: Player,
    ...args: unknown[]
  ): void;
  FireServer(memberName: string, ...args: unknown[]): void;
  PromiseFireServer(
    memberName: string,
    ...args: unknown[]
  ): Promise<RemoteEvent | BindableEvent>;
  InvokeServer(memberName: string, ...args: unknown[]): unknown;
  PromiseInvokeServer(memberName: string, ...args: unknown[]): Promise<unknown>;
  PromiseInvokeClient(
    memberName: string,
    player: Player,
    ...args: unknown[]
  ): Promise<unknown>;
  GetContainerClass(): string;
  Destroy(): void;
} & {
  [memberName: string]: RemotingMember;
};

interface RemotingConstructor {
  readonly ClassName: 'Remoting';
  new (
    instance: Instance,
    name: string,
    remotingRealm?: RemotingRealm
  ): Remoting;
}

export const Remoting: RemotingConstructor;
