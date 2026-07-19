interface QuaternionObject {
  toCFrame(position: Vector3): CFrame;
  inv(): QuaternionObject;
  unm(): QuaternionObject;
  add(other: QuaternionObject): QuaternionObject;
  sub(other: QuaternionObject): QuaternionObject;
  mul(other: QuaternionObject | number): QuaternionObject;
  div(other: QuaternionObject | number): QuaternionObject;
  pow(exponent: QuaternionObject | number): QuaternionObject;
  length(): number;
  magnitude(): number;
  tostring(): string;
  log(): QuaternionObject;
  exp(): QuaternionObject;
  normalize(): QuaternionObject;
  unit(): QuaternionObject;
  sqrt(): QuaternionObject;
}

interface QuaternionObjectConstructor {
  new (w: number, x: number, y: number, z: number): QuaternionObject;

  fromCFrame: (cframe: CFrame) => QuaternionObject;
}

export const QuaternionObject: QuaternionObjectConstructor;
