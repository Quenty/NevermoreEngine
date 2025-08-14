import { Maid } from '../../../maid';

export namespace AttributeUtils {
  function isValidAttributeType(valueType: string): boolean;
  function promiseAttribute<T = unknown>(
    instance: Instance,
    attributeName: string,
    predicate?: (value: any) => boolean,
    cancelToken?: CancelToken
  ): Promise<T>;
  function bindToBinder(
    instance: Instance,
    attributeName: string,
    binder: Binder
  ): Maid;
  function initAttribute(
    instance: Instance,
    attributeName: string,
    defaultValue: any
  ): any;
  function getAttribute(
    instance: Instance,
    attributeName: string,
    defaultValue: any
  ): any;
  function removeAllAttributes(instance: Instance): void;
}
