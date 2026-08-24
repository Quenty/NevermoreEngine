type SerializedCFrame = [number, number, number, number, number, number] & {
  __brand: 'SerializedCFrame';
};

export namespace CFrameSerializer {
  function outputRotationAzure(cframe: CFrame): SerializedCFrame;
  function toJSONString(cframe: CFrame): string;
  function isRotationAzure(value: unknown): value is SerializedCFrame;
  function fromJSONString(str: string): CFrame | undefined;
  function readPosition(data: SerializedCFrame): Vector3;
  function readRotationAzure(data: SerializedCFrame): CFrame;
}
