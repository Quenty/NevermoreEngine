export const onRenderStepFrame: (
  priority: number,
  callback: () => void
) => () => void;
