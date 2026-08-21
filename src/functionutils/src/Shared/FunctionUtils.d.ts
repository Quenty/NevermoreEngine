export namespace FunctionUtils {
  function bind<S, A extends unknown[], R>(
    self: S,
    func: (self: S, ...args: A) => R
  ): (...args: A) => R;
}
