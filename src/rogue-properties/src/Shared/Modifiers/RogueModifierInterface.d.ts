import {
  TieDefinition,
  TieDefinitionMethod,
  TieDefinitionProperty,
} from '@quenty/tie';

export const RogueModifierInterface: TieDefinition<{
  Order: TieDefinitionProperty;
  Source: TieDefinitionProperty;

  GetModifiedVersion: TieDefinitionMethod;
  ObserveModifiedVersion: TieDefinitionMethod;
  GetInvertedVersion: TieDefinitionMethod;
}>;
