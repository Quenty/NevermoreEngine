import { Maid } from '../../../maid';

export namespace NoCollisionConstraintUtils {
  function create(
    part0: BasePart,
    part1: BasePart,
    parent?: Instance
  ): NoCollisionConstraint;
  function tempNoCollision(
    parts0: BasePart[],
    parts1: BasePart[],
    parent?: Instance
  ): Maid;
  function createBetweenPartsLists(
    parts0: BasePart[],
    parts1: BasePart[],
    parent?: Instance | boolean
  ): NoCollisionConstraint[];
  function createBetweenMechanisms(
    adornee0: BasePart,
    adornee1: BasePart,
    parent?: Instance
  ): NoCollisionConstraint[];
}
