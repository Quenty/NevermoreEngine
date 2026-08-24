import { PagesDatabase } from './PagesDatabase';

interface PagesProxy<T extends Pages | PagesDatabase<unknown>> {
  readonly IsFinished: boolean;
  AdvanceToNextPageAsync(): void;
  GetCurrentPage(): T extends PagesDatabase<infer U>
    ? U[]
    : T extends Pages<infer U>
    ? U[]
    : unknown[];
  Clone(): PagesProxy<T>;
}

interface PagesProxyConstructor {
  readonly ClassName: 'PagesProxy';
  new <T extends Pages | PagesDatabase<unknown>>(database: T): PagesProxy<T>;

  isPagesProxy: (value: unknown) => value is PagesProxy<PagesDatabase<unknown>>;
}

export const PagesProxy: PagesProxyConstructor;
