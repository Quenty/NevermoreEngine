export const trajectory: (
  origin: Vector3,
  target: Vector3,
  initialVelocity: number,
  gravityForce: number
) => LuaTuple<
  | [
      lowTrajectory: Vector3,
      highTrajectory: Vector3,
      fallbackTrajectory: undefined
    ]
  | [
      lowTrajectory: undefined,
      highTrajectory: undefined,
      fallbackTrajectory: Vector3
    ]
>;
