import { CancelToken } from '@quenty/canceltoken';
import { Promise } from '@quenty/promise';
import { Observable } from '@quenty/rx';

export namespace AdorneeConditionUtils {
  function observeConditionsMet(
    conditionObj: BindableFunction,
    adornee: Instance
  ): Observable<boolean>;
  function promiseQueryConditionsMet(
    conditionObj: BindableFunction,
    adornee: Instance,
    cancelToken?: CancelToken
  ): Promise<boolean>;
  function createConditionContainer(): BindableFunction;
  function create(observeCallback: () => boolean): BindableFunction;
  function createRequiredProperty(
    propertyName: string,
    requiredValue: unknown
  ): BindableFunction;
  function createRequiredAttribute(
    attributeName: string,
    attributeValue: unknown
  ): BindableFunction;
  function createRequiredTieInterface(
    tieInterfaceDefinition: unknown
  ): BindableFunction;
  function createOrConditionGroup(): BindableFunction;
  function createAndConditionGroup(): BindableFunction;
  function getRequiredTag(): string;
  function getConditionNamePostfix(): string;
  function setValueWhenEmpty(container: BindableFunction, value: boolean): void;
  function getValueWhenEmpty(container: BindableFunction): boolean;
  function observeValueWhenEmpty(
    container: BindableFunction
  ): Observable<boolean>;
}
