export namespace MessagingServiceUtils {
  function promisePublish(topic: string, message?: unknown): Promise<void>;
  function promiseSubscribe(
    topic: string,
    callback: (...args: unknown[]) => unknown
  ): Promise<RBXScriptConnection>;
}
