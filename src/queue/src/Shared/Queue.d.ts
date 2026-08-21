type Queue<T = unknown> = {
  PushLeft(value: T): void;
  PushRight(value: T): void;
  PopLeft(): T;
  PopRight(): T;
  IsEmpty(): boolean;
  GetCount(): number;
  Destroy(): void;
  __len(): number;
};

interface QueueConstructor {
  readonly ClassName: 'Queue';
  new <T>(): Queue<T>;
}

export const Queue: QueueConstructor;
