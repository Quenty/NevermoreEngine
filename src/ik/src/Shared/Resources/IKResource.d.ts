import { BaseObject } from '@quenty/baseobject';
import { Signal } from '@quenty/signal';

export interface IKResourceData {
  name: string;
  robloxName: string;
}

interface IKResource extends BaseObject {
  ReadyChanged: Signal<boolean>;
  GetData(): IKResourceData;
  IsReady(): boolean;
  Get(descendantName: string): Instance;
  GetInstance(): Instance | undefined;
  SetInstance(instance: Instance | undefined): void;
  GetLookupTable(): Readonly<Record<string, IKResource>>;
}

interface IKResourceConstructor {
  readonly ClassName: 'IKResource';
  new (data: IKResourceData): IKResource;
}

export const IKResource: IKResourceConstructor;
