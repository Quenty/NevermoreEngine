export type RoundingBehaviourType =
  (typeof RoundingBehaviourTypes)[keyof typeof RoundingBehaviourTypes];

export const RoundingBehaviourTypes: Readonly<{
  ROUND_TO_CLOSEST: 'roundToClosest';
  TRUNCATE: 'truncate';
  NONE: 'none';
}>;
