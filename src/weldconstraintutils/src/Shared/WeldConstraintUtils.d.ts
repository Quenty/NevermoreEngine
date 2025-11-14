export namespace WeldConstraintUtils {
  function namedBetween(
    name: string,
    part0: BasePart,
    part1: BasePart,
    parent?: Instance
  ): Weld | WeldConstraint;
  function namedBetweenForceWeldConstraint(
    name: string,
    part0: BasePart,
    part1: BasePart,
    parent?: Instance
  ): WeldConstraint;
}
