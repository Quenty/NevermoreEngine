import { Maid } from '@quenty/maid';

export class BaseObject<T extends Instance | undefined = undefined> {
  public static readonly ClassName: 'BaseObject';
  protected _obj: T;
  protected _maid: Maid;
  constructor(instance?: T);
  public Destroy(): void;
}
