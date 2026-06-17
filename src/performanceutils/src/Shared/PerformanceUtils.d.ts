interface CounterData {
  total: number;
  formatter: (value: number) => string;
}

export namespace PerformanceUtils {
  function profileTimeBegin(label: string): () => void;
  function profileTimeEnd(): void;
  function incrementCounter(label: string, amount?: number): void;
  function readCounter(label: string): number;
  function getOrCreateCounter(label: string): CounterData;
  function setLabelFormat(
    label: string,
    formatter: (value: number) => string
  ): void;
  function formatAsMilliseconds(value: number): string;
  function formatAsCalls(value: number): string;
  function countCalls<T>(label: string, object: T, method: keyof T): void;
  function countLibraryCalls(prefix: string, library: unknown): void;
  function countCallTime<T>(label: string, object: T, method: keyof T): void;
  function countObject(label: string, object: unknown): void;
  function trackObjectConstruction(object: unknown): void;
  function printAll(): void;
}
