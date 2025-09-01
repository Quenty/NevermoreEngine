type ValueTypeToDefaultValueType = {
  boolean: false;
  BrickColor: BrickColor;
  CFrame: CFrame;
  Color3: Color3;
  ColorSequence: ColorSequence;
  ColorSequenceKeypoint: ColorSequenceKeypoint;
  number: 0;
  PhysicalProperties: PhysicalProperties;
  NumberRange: NumberRange;
  NumberSequence: NumberSequence;
  NumberSequenceKeypoint: NumberSequenceKeypoint;
  Ray: Ray;
  Rect: Rect;
  Region3: Region3;
  Region3int16: Region3int16;
  string: '';
  UDim: UDim;
  UDim2: UDim2;
  userdata: userdata;
  Vector2: Vector2;
  Vector2int16: Vector2int16;
  Vector3: Vector3;
  Vector3int16: Vector3int16;
  table: {};
  nil: undefined;
  Random: Random;
  RaycastParams: RaycastParams;
  OverlapParams: OverlapParams;
};

export namespace DefaultValueUtils {
  function getDefaultValueForType(typeOfName: string): unknown;
  function getDefaultValueForType<T extends keyof ValueTypeToDefaultValueType>(
    typeOfName: T
  ): ValueTypeToDefaultValueType[T];
  function toDefaultValue(value: unknown): unknown;
  function toDefaultValue<T extends keyof ValueTypeToDefaultValueType>(
    value: T
  ): ValueTypeToDefaultValueType[T];
}
