import { Binder } from '@quenty/binder';
import { CooldownBase } from './Binders/CooldownBase';

export namespace CooldownUtils {
  function create(parent: Instance, length: number): NumberValue;
  function findCooldown<T extends CooldownBase>(
    cooldownBinder: Binder<T>,
    parent: Instance
  ): T | undefined;
  function clone(cooldown: NumberValue): NumberValue;
}
