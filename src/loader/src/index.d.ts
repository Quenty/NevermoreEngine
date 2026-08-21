type Loader = Record<string, unknown> & {
  __call(request: string | ModuleScript): unknown;
  Destroy(): void;
};

interface LoaderConstructor {
  readonly ClassName: 'Loader';
  new (
    packages: Instance,
    replicationType: 'client' | 'server' | 'shared' | 'plugin'
  ): Loader;

  bootstrapGame: (packages: Instance) => Loader;
  bootstrapPlugin: (packages: Instance) => Loader;
  bootstrapStory: (storyScript: Instance) => Loader;
  load: (packagesOrModuleScript: Instance) => Loader;
}

export const Loader: LoaderConstructor;
