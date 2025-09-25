import { Promise } from '@quenty/promise';
import { ServiceBag } from '@quenty/servicebag';
import { Cmdr, CommandContext, CommandDefinition } from '../Shared/CmdrTypes';

export interface CmdrService {
  readonly ServiceName: 'CmdrService';
  Init(serviceBag: ServiceBag): void;
  PromiseCmdr(): Promise<Cmdr>;
  RegisterCommand(
    commandData: CommandDefinition,
    execute: (context: CommandContext, ...args: unknown[]) => string | undefined
  ): void;
  Destroy(): void;
}
