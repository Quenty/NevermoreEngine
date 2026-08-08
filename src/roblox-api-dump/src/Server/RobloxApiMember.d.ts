export interface RobloxApiMemberData {
  Category: string;
  MemberType: string;
  Name: string;
  Security: {
    Read: string;
    Write: string;
  };
  Serialization: {
    CanLoad: boolean;
    CanSave: boolean;
  };
  Tags: string[];
  ThreadSafety: string;
  ValueType: {
    Category: string;
    Name: string;
  };
}

interface RobloxApiMember {
  GetTypeName(): string | undefined;
  GetName(): string;
  GetCategory(): string;
  IsReadOnly(): boolean;
  GetMemberType(): string;
  IsEvent(): boolean;
  GetRawData(): Readonly<RobloxApiMemberData>;
  IsWriteNotAccessibleSecurity(): boolean;
  IsReadNotAccessibleSecurity(): boolean;
  IsWriteLocalUserSecurity(): boolean;
  IsReadLocalUserSecurity(): boolean;
  IsReadRobloxScriptSecurity(): boolean;
  IsWriteRobloxScriptSecurity(): boolean;
  IsWriteRobloxSecurity(): boolean;
  CanSerializeSave(): boolean | undefined;
  CanSerializeLoad(): boolean | undefined;
  GetWriteSecurity(): string | undefined;
  GetReadSecurity(): string | undefined;
  IsProperty(): boolean;
  IsFunction(): boolean;
  IsCallback(): boolean;
  IsNotScriptable(): boolean;
  IsNotReplicated(): boolean;
  IsDeprecated(): boolean;
  IsHidden(): boolean;
  GetTags(): readonly string[];
  HasTag(tagName: string): boolean;
}

interface RobloxApiMemberConstructor {
  readonly ClassName: 'RobloxApiMember';
  new (data: RobloxApiMemberData): RobloxApiMember;
}

export const RobloxApiMember: RobloxApiMemberConstructor;
