import { TieDefinition, TieDefinitionMethod } from '@quenty/tie';

export const PlayerProductManagerInterface: TieDefinition<{
  GetPlayer: TieDefinitionMethod;
  IsOwnable: TieDefinitionMethod;
  IsPromptOpen: TieDefinitionMethod;
  PromisePlayerPromptClosed: TieDefinitionMethod;
  GetAssetTrackerOrError: TieDefinitionMethod;
  GetOwnershipTrackerOrError: TieDefinitionMethod;
}>;
