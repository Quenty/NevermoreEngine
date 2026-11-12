export interface StudioBridgeErrorOptions {
  code: string;
  message: string;
  fix?: string;
  cause?: unknown;
}

/** An expected failure, said in the user's terms, with the one thing to do about it. */
export class StudioBridgeError extends Error {
  public readonly code: string;
  public readonly fix: string | undefined;

  constructor({ code, message, fix, cause }: StudioBridgeErrorOptions) {
    super(message, cause === undefined ? undefined : { cause });
    this.name = 'StudioBridgeError';
    this.code = code;
    this.fix = fix;
  }
}

export function invalidInput(message: string, fix?: string): StudioBridgeError {
  return new StudioBridgeError({ code: 'INVALID_INPUT', message, fix });
}
