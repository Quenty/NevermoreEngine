export namespace PagesUtils {
  function promiseAdvanceTonextPage<T extends Pages>(
    pages: T
  ): Promise<T extends Pages<infer U> ? U[] : unknown[]>;
}
