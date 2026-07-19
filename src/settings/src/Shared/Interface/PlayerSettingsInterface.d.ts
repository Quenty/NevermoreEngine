import { TieDefinition, TieDefinitionMethod } from '@quenty/tie';

export const PlayerSettingsInterface: TieDefinition<{
  GetSettingProperty: TieDefinitionMethod;
  GetValue: TieDefinitionMethod;
  SetValue: TieDefinitionMethod;
  ObserveValue: TieDefinitionMethod;
  RestoreDefault: TieDefinitionMethod;
  EnsureInitialized: TieDefinitionMethod;
  GetPlayer: TieDefinitionMethod;
}>;
