import { Binder } from './Binder';

export namespace BinderUtils {
  function findFirstAncestor<T>(
    binder: Binder<T>,
    child: Instance
  ): T | undefined;
  function findFirstChild<T>(
    binder: Binder<T>,
    parent: Instance
  ): T | undefined;
  function getChildren<T>(binder: Binder<T>, parent: Instance): T[];
  function mapBinderListToTable<K, V>(
    bindersList: Map<unknown, Binder<unknown>>
  ): Map<string, Binder<unknown>>;
  function getMappedFromList(tagsMap: Map<string, Binder<unknown>>): unknown[];
  function getChildrenOfBinders<T>(
    bindersList: Binder<T>[],
    parent: Instance
  ): T[];
  function getLinkedChildren<T>(
    binder: Binder<T>,
    linkName: string,
    parent: Instance
  ): T[];
  function getDescendants<T>(binder: Binder<T>, parent: Instance): T[];
}
