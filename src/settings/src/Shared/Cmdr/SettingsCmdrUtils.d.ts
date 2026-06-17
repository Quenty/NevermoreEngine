import { Cmdr, CmdrClient } from '@quenty/cmdrservice';
import { ServiceBag } from '@quenty/servicebag';

export namespace SettingsCmdrUtils {
  function registerSettingDefinition(
    cmdr: Cmdr | CmdrClient,
    serviceBag: ServiceBag
  ): void;
}
