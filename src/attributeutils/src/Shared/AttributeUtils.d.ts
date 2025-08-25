import { Binder } from '@quenty/binder';
import { Maid } from '@quenty/maid';

export namespace AttributeUtils {
  function isValidAttributeType(valueType: string): boolean;
  function promiseAttribute<T = unknown>(
    instance: Instance,
    attributeName: string,
    predicate?: (value: T) => boolean,
    cancelToken?: CancelToken
  ): Promise<T>;
  function bindToBinder(
    instance: Instance,
    attributeName: string,
    binder: Binder<unknown>
  ): Maid;
  function initAttribute<T>(
    instance: Instance,
    attributeName: string,
    defaultValue: T
  ): T;
  function getAttribute<T = unknown>(
    instance: Instance,
    attributeName: string,
    defaultValue?: T
  ): T;
  function removeAllAttributes(instance: Instance): void;
}
