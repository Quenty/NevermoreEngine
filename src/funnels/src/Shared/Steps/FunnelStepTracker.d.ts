import { BaseObject } from '@quenty/baseobject';
import { Signal } from '@quenty/signal';

interface FunnelStepTracker extends BaseObject {
  StepLogged: Signal<[stepNumber: number, stepName: string]>;

  LogStep(stepNumber: number, stepName: string): void;
  IsStepComplete(stepNumber: number): boolean;
  GetLoggedSteps(): { [stepNumber: number]: string };
  ClearLoggedSteps(): void;
}

interface FunnelStepTrackerConstructor {
  readonly ClassName: 'FunnelStepTracker';
  new (): FunnelStepTracker;
}

export const FunnelStepTracker: FunnelStepTrackerConstructor;
