import { BaseObject } from '@quenty/baseobject';
import { RobloxApiClass, RobloxApiClassData } from './RobloxApiClass';
import { RobloxApiEnumData } from './RobloxApiUtils';
import { Promise } from '@quenty/promise';
import { RobloxApiMember } from './RobloxApiMember';

export interface RobloxApiDumpData {
  Classes: RobloxApiClassData[];
  Enums: RobloxApiEnumData[];
  Version: number;
}

interface RobloxApiDump extends BaseObject {
  PromiseClass(className: string): Promise<RobloxApiClass>;
  PromiseMembers(className: string): Promise<RobloxApiMember[]>;
}

interface RobloxApiDumpConstructor {
  readonly ClassName: 'RobloxApiDump';
  new (): RobloxApiDump;
}

export const RobloxApiDump: RobloxApiDumpConstructor;
