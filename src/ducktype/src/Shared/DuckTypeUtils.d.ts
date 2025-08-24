export namespace DuckTypeUtils {
  function isImplementation<T extends { new (...args: unknown[]): T }>(
    template: unknown,
    target: T
  ): template is T;
}
