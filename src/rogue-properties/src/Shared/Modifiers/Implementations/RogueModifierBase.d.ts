import { AttributeValue } from '@quenty/attributeutils';
import { Observable } from '@quenty/rx';
import { ServiceBag } from '@quenty/servicebag';

interface RogueModifierBase {
  Order: AttributeValue<number>;
  Source: ObjectValue;

  GetModifiedVersion(value: number): number;
  ObserveModifiedVersion(value: number): Observable<number>;
  GetInvertedVersion(value: number): number;
}

interface RogueModifierBaseConstructor {
  readonly ClassName: 'RogueModifierBase';
  new (obj: ValueBase, serviceBag: ServiceBag): RogueModifierBase;
}

export const RogueModifierBase: RogueModifierBaseConstructor;
