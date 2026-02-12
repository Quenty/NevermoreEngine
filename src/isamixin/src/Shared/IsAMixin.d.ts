export interface IsAMixin {
  IsA(className: string): boolean;
  CustomIsA(className: string): boolean;
}

export const IsAMixin: {
  Add(classObj: { new (...args: unknown[]): unknown }): void;
};
