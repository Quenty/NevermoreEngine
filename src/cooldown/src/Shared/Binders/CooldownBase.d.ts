import { BaseObject } from '@quenty/baseobject';
import { ServiceBag } from '@quenty/servicebag';
import { Signal } from '@quenty/signal';
import { CooldownModel } from '../Model/CooldownModel';

interface CooldownBase extends BaseObject {
  Done: Signal;
  GetCooldownModel(): CooldownModel;
  GetObject(): NumberValue;
  GetTimePassed(): number;
  GetTimeRemaining(): number;
  GetEndTime(): number;
  GetStartTime(): number;
  GetLength(): number;
}

interface CooldownBaseConstructor {
  readonly ClassName: 'CooldownBase';
  new (numberValue: NumberValue, serviceBag: ServiceBag): CooldownBase;
}

export const CooldownBase: CooldownBaseConstructor;
