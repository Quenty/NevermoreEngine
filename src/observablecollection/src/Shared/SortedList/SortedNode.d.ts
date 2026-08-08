type CompareFunction<T> = (a: T, b: T) => number;
type WrappedIterator<T> = (...values: unknown[]) => T[];

type SortedNode<T> = {
  IterateNodes(): WrappedIterator<[number, SortedNode<T>]>;
  IterateData(): WrappedIterator<[number, T]>;
  IterateNodesRange(
    start: number,
    finish?: number
  ): WrappedIterator<[number, SortedNode<T>]>;
  FindNodeAtIndex(searchIndex: number): SortedNode<T> | undefined;
  FindNodeIndex(node: SortedNode<T>): number | undefined;
  GetIndex(): number;
  FindFirstNodeForData(data: T): SortedNode<T> | undefined;
  NeedsToMove(root: SortedNode<T> | undefined, newValue: number): boolean;
  ContainsNode(node: SortedNode<T>): boolean;
  MarkBlack(): void;
  InsertNode(node: SortedNode<T>): SortedNode<T>;
  RemoveNode(node: SortedNode<T>): SortedNode<T>;
} & IterableFunction<LuaTuple<[index: number, value: T]>>;

interface SortedNodeConstructor {
  readonly ClassName: 'SortedNode';
  new <T>(data: T): SortedNode<T>;

  isSortedNode(value: unknown): value is SortedNode<unknown>;
}

export const SortedNode: SortedNodeConstructor;
