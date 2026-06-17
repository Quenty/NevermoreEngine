import { BaseObject } from '@quenty/baseobject';

interface FunnelStepLogger extends BaseObject {
  SetPrintDebugEnabled(debugEnabled: boolean): void;
  LogStep(stepNumber: number, stepName: string): void;
  IsStepComplete(stepNumber: number): boolean;
}

interface FunnelStepLoggerConstructor {
  readonly ClassName: 'FunnelStepLogger';
  new (): FunnelStepLogger;
}

export const FunnelStepLogger: FunnelStepLoggerConstructor;
