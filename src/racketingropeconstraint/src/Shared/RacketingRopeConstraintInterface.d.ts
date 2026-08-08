import {
  TieDefinition,
  TieDefinitionMethod,
} from '@quenty/tie/src/Shared/TieDefinition';

export const RacketingRopeConstraintInterface: TieDefinition<{
  PromiseConstrained: TieDefinitionMethod;
  ObserveIsConstrained: TieDefinitionMethod;
}>;
