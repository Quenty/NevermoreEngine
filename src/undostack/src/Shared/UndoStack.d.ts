import { BaseObject } from '@quenty/baseobject';
import { Observable } from '@quenty/rx';
import { UndoStackEntry } from './UndoStackEntry';
import { Promise } from '@quenty/promise';

interface UndoStack extends BaseObject {
  ClearRedoStack(): void;
  IsActionExecuting(): boolean;
  ObserveHasUndoEntries(): Observable<boolean>;
  ObserveHasRedoEntries(): Observable<boolean>;
  HasUndoEntries(): boolean;
  HasRedoEntries(): boolean;
  Push(undoStackEntry: UndoStackEntry): () => void;
  Remove(undoStackEntry: UndoStackEntry): void;
  PromiseUndo(): Promise;
  PromiseRedo(): Promise;
}

interface UndoStackConstructor {
  readonly ClassName: 'UndoStack';
  new (maxSize?: number): UndoStack;
}

export const UndoStack: UndoStackConstructor;
