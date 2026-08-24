export namespace PreferredParentUtils {
  function createPreferredParentRetriever(
    parent: Instance,
    name: string,
    forceCreate?: boolean
  ): () => Instance;
  function getPreferredParent(
    parent: Instance,
    name: string,
    forceCreate?: boolean
  ): Instance;
}
