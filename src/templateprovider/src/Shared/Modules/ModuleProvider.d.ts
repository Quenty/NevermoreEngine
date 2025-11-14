interface ModuleProvider {
  Init(): void;
  GetModules(): unknown[];
  GetFromName(name: string): unknown;
}

interface ModuleProviderConstructor {
  readonly ClassName: 'ModuleProvider';
  readonly ServiceName: 'ModuleProvider';
  new (
    parent: Instance,
    checkModule?: (_module: unknown, moduleScript: ModuleScript) => void,
    initModule?: (_module: unknown, moduleScript: ModuleScript) => void,
    sortList?: (list: unknown[]) => void
  ): ModuleProvider;
}

export const ModuleProvider: ModuleProviderConstructor;
