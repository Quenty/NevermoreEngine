export namespace CollectionServiceUtils {
  function findFirstAncestor(
    tagName: string,
    child: Instance
  ): Instance | undefined;
  function findInstanceOrFirstAncestor(
    tagName: string,
    child: Instance
  ): Instance | undefined;
  function removeAllTags(instance: Instance): void;
}
