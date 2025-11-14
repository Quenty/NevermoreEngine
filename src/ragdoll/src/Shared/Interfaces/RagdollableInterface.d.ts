import {
  TieDefinition,
  TieDefinitionMethod,
  TieDefinitionSignal,
} from '@quenty/tie';

export const RagdollableInterface: TieDefinition<{
  Ragdolled: TieDefinitionSignal;
  Unragdolled: TieDefinitionSignal;
  Ragdoll: TieDefinitionMethod;
  Unragdoll: TieDefinitionMethod;
  ObserveIsRagdolled: TieDefinitionMethod;
  IsRagdolled: TieDefinitionMethod;
}>;
