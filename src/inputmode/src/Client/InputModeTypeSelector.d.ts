import { ServiceBag } from '@quenty/servicebag';
import { InputModeType } from '../Shared/InputModeType';
import { Signal } from '@quenty/signal';
import { Observable } from '@quenty/rx';
import { Brio } from '@quenty/brio';
import { Maid } from '@quenty/maid';

interface InputModeTypeSelector {
  Changed: Signal<[newMode: InputModeType, oldMode?: InputModeType]>;
  readonly Value: InputModeType | undefined;
  GetActiveInputType(): InputModeType | undefined;
  ObserveActiveInputType(): Observable<InputModeType | undefined>;
  IsActive(inputModeType: InputModeType): boolean;
  ObserveIsActive(inputModeType: InputModeType): Observable<boolean>;
  Bind(
    updateBindFunction: (
      inputModeType: InputModeType | undefined,
      maid: Maid
    ) => void
  ): this;
  RemoveInputModeType(inputModeType: InputModeType): void;
  AddInputModeType(inputModeType: InputModeType): void;
  Destroy(): void;
}

interface InputModeTypeSelectorConstructor {
  readonly ClassName: 'InputModeTypeSelector';
  new (
    serviceBag: ServiceBag,
    inputModesTypes?: InputModeType[]
  ): InputModeTypeSelector;

  fromObservableBrio: (
    ServiceBag: ServiceBag,
    observeInputModesBrio: Observable<Brio<InputModeType>>
  ) => InputModeTypeSelector;
}

export const InputModeTypeSelector: InputModeTypeSelectorConstructor;
