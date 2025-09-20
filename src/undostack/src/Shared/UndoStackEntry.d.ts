import { BaseObject } from '@quenty/baseobject';
import { Maid } from '@quenty/maid';
import { Promise } from '@quenty/promise';
import { Signal } from '@quenty/signal';

interface UndoStackEntry extends BaseObject {
  Destroying: Signal;
  SetPromiseUndo(promiseUndo?: (maid: Maid) => Promise | unknown): void;
  SetPromiseRedo(promiseUndo?: (maid: Maid) => Promise | unknown): void;
  HasUndo(): boolean;
  HasRedo(): boolean;
  PromiseUndo(maid: Maid): Promise;
  PromiseRedo(maid: Maid): Promise;
}

interface UndoStackEntryConstructor {
  readonly ClassName: 'UndoStackEntry';
  new (): UndoStackEntry;

  isUndoStackEntry: (value: unknown) => value is UndoStackEntry;
}

export const UndoStackEntry: UndoStackEntryConstructor;
