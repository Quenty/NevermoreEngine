interface PartTouchingCalculator {
  CheckIfTouchingHumanoid(humanoid: Humanoid, parts: BasePart[]): boolean;
  GetCollidingPartFromParts(
    parts: BasePart[],
    relativeTo?: CFrame,
    padding?: number
  ): BasePart;
  GetTouchingBoundingBox(
    parts: BasePart[],
    relativeTo?: CFrame,
    padding?: number
  ): BasePart[];
  GetTouchingHull(parts: BasePart[], padding?: number): BasePart[];
  GetTouching(basePart: BasePart, padding?: number): BasePart[];
  GetTouchingHumanoids(touchingList: BasePart[]): {
    Humanoid: Humanoid;
    Character?: Model;
    Player?: Player;
    Touching: BasePart[];
  }[];
}

interface PartTouchingCalculatorConstructor {
  readonly ClassName: 'PartTouchingCalculator';
  new (): PartTouchingCalculator;
}

export const PartTouchingCalculator: PartTouchingCalculatorConstructor;
