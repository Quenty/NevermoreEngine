export type MaidTask =
  | (() => unknown)
  | thread
  | RBXScriptConnection
  | Maid
  | {
      Destroy(): void;
    };

type Maid = {
  [index in number | string]: MaidTask | undefined;
} & {
  GiveTask(task: MaidTask): number;
  DoCleaning(): void;
  Destroy(): void;
} & Map<unknown, MaidTask | undefined>;

interface MaidConstructor {
  readonly ClassName: 'Maid';
  new (): Maid;
}

export const Maid: MaidConstructor;
