export interface GenerateWithMixin {}

export const GenerateWithMixin: {
  Add(
    classObj: { new (...args: unknown[]): unknown },
    staticResources: string[]
  ): void;
};
