interface DataStoreWriter {}

interface DataStoreWriterConstructor {
  readonly ClassName: 'DataStoreWriter';
  new (): DataStoreWriter;
}

export const DataStoreWriter: DataStoreWriterConstructor;
