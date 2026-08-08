import { TieDefinition, TieDefinitionMethod } from '@quenty/tie';

export const IKRigInterface: TieDefinition<{
  GetPlayer: TieDefinitionMethod;
  GetHumanoid: TieDefinitionMethod;

  PromiseLeftArm: TieDefinitionMethod;
  PromiseRightArm: TieDefinitionMethod;
  GetLeftArm: TieDefinitionMethod;
  GetRightArm: TieDefinitionMethod;

  GetAimPosition: TieDefinitionMethod;
}>;
