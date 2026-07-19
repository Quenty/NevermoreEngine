export const BlendDefaultProps: {
  [K in keyof Instances]?: Instances[K] extends Instance
    ? Partial<WritableInstanceProperties<Instances[K]>>
    : never;
};
