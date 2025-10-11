interface PagesDatabase<T> {
  IncrementToPageIdAsync(pageId: number): void;
  GetPage(pageId: number): T extends Pages<infer U> ? U[] : unknown[];
  GetIsFinished(pageId: number): boolean;
}

interface PagesDatabaseConstructor {
  readonly ClassName: 'PagesDatabase';
  new <T extends Pages>(pages: T): PagesDatabase<T>;

  isPagesDatabase: (value: unknown) => value is PagesDatabase<unknown>;
}

export const PagesDatabase: PagesDatabaseConstructor;
