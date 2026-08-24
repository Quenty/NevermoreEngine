import { Binder } from '@quenty/binder';
import { PartTouchingCalculator } from './PartTouchingCalculator';

interface BinderTouchingCalculator extends PartTouchingCalculator {
  GetTouchingClass<T>(
    binder: Binder<T>,
    touchingList: BasePart[],
    ignoreObject?: Instance
  ): {
    Object: T;
    Touching: BasePart[];
  }[];
}

interface BinderTouchingCalculatorConstructor {
  readonly ClassName: 'BinderTouchingCalculator';
  new (): BinderTouchingCalculator;
}

export const BinderTouchingCalculator: BinderTouchingCalculatorConstructor;
