import {
  TieDefinition,
  TieDefinitionMethod,
  TieDefinitionSignal,
} from '@quenty/tie';

export const PlayerAssetMarketTrackerInterface: TieDefinition<{
  ObservePromptOpenCount: TieDefinitionMethod;
  ObserveAssetPurchased: TieDefinitionMethod;
  PromisePromptPurchase: TieDefinitionMethod;
  HasPurchasedThisSession: TieDefinitionMethod;
  IsPromptOpen: TieDefinitionMethod;

  Purchased: TieDefinitionSignal;
  PromptClosed: TieDefinitionSignal;
  ShowPromptRequested: TieDefinitionSignal;
}>;
