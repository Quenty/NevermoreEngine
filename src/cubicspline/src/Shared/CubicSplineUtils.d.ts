interface CubicSplineNode<T> {
  t: number;
  p: T;
  v: T;
  optimize?: boolean;
}

export namespace CubicSplineUtils {
  function newSplineNode<T>(
    t: number,
    position: T,
    velocity: T
  ): CubicSplineNode<T>;
  function tween<T>(
    nodeList: CubicSplineNode<T>[],
    t: number
  ): CubicSplineNode<T> | undefined;
  function cloneSplineNode<T>(node: CubicSplineNode<T>): CubicSplineNode<T>;
  function tweenSplineNodes<T>(
    node0: CubicSplineNode<T>,
    node1: CubicSplineNode<T>,
    t: number
  ): CubicSplineNode<T>;
  function sort<T>(nodeList: CubicSplineNode<T>[]): void;
  function populateVelocities<T>(
    nodeList: CubicSplineNode<T>[],
    index0?: number,
    index1?: number
  ): void;
}
