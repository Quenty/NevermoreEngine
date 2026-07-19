interface ThrottledFunction<Args = void> {
  Call(...args: Args extends unknown[] ? Args : [Args]): void;
  Destroy(): void;
}

interface ThrottleConfig {
  leading?: boolean;
  trailing?: boolean;
  leadingFirstTimeOnly?: boolean;
}

interface ThrottledFunctionConstructor {
  readonly ClassName: 'ThrottledFunction';
  new <Args>(
    timeoutInSeconds: number,
    func: (...args: Args extends unknown[] ? Args : [Args]) => void,
    config?: ThrottleConfig
  ): ThrottledFunction<Args>;
}

export const ThrottledFunction: ThrottledFunctionConstructor;
