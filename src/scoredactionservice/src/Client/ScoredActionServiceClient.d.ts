import { InputKeyMapList } from '@quenty/inputkeymaputils';
import { ServiceBag } from '@quenty/servicebag';
import { ScoredAction } from './ScoredAction';
import { ValueObject } from '@quenty/valueobject';
import { Operator } from '@quenty/rx';

export interface ScoredActionServiceClient {
  readonly ServiceName: 'ScoredActionServiceClient';
  Init(serviceBag: ServiceBag): void;
  Start(): void;
  GetScoredAction(inputKeyMapList: InputKeyMapList): ScoredAction;
  ObserveNewFromInputKeyMapList(
    scoreValue: ValueObject<number>
  ): Operator<InputKeyMapList, ScoredAction>;
  Destroy(): void;
}
