import { BaseObject } from '@quenty/baseobject';
import { Observable } from '@quenty/rx';
import { CooldownModel } from './CooldownModel';
import { Brio } from '@quenty/brio';
import { Mountable } from '@quenty/valueobject';

interface CooldownTrackerModel extends BaseObject {
  IsCoolingDown(): boolean;
  ObserveActiveCooldownModel(): Observable<CooldownModel>;
  ObserveActiveCooldownModelBrio(): Observable<Brio<CooldownModel>>;
  SetCooldownModel(
    cooldownModel: Mountable<CooldownModel | undefined>
  ): () => void;
}

interface CooldownTrackerModelConstructor {
  readonly ClassName: 'CooldownTrackerModel';
  new (): CooldownTrackerModel;

  isCooldownTrackerModel: (value: unknown) => value is CooldownTrackerModel;
}

export const CooldownTrackerModel: CooldownTrackerModelConstructor;
