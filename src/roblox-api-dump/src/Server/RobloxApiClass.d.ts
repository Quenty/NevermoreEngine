import { Promise } from '@quenty/promise';
import { RobloxApiMember, RobloxApiMemberData } from './RobloxApiMember';
import { RobloxApiDump } from './RobloxApiDump';

export interface RobloxApiClassData {
  Members: RobloxApiMemberData[];
  MemoryCategory: string;
  Name: string;
  Superclass: string;
  Tags: string[];
}

interface RobloxApiClass {
  GetRawData(): RobloxApiClassData;
  GetClassName(): string;
  GetMemberCategory(): string | undefined;
  PromiseSuperClass(): Promise<RobloxApiClass>;
  PromiseIsA(className: string): Promise<boolean>;
  PromiseIsDescendantOf(className: string): Promise<boolean>;
  PromiseAllSuperClasses(): Promise<RobloxApiClass[]>;
  GetSuperClassName(): string | undefined;
  HasSuperClass(): boolean;
  PromiseMembers(): Promise<RobloxApiMember[]>;
  PromiseProperties(): Promise<RobloxApiMember[]>;
  PromiseEvents(): Promise<RobloxApiMember[]>;
  PromiseFunctions(): Promise<RobloxApiMember[]>;
  IsService(): boolean;
  IsNotCreatable(): boolean;
  IsNotReplicated(): boolean;
  HasTag(tagName: string): boolean;
}

interface RobloxApiClassConstructor {
  readonly ClassName: 'RobloxApiClass';
  new (robloxApiDump: RobloxApiDump, data: RobloxApiClassData): RobloxApiClass;
}

export const RobloxApiClass: RobloxApiClassConstructor;
