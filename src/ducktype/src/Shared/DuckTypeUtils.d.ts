export namespace DuckTypeUtils {
  function isImplementation<T>(
    template: unknown,
    target: { new (...args: unknown[]): T }
  ): template is T;
}
