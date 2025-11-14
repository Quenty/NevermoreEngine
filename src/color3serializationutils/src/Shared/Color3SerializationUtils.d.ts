export type SerializedColor3 = [r: number, g: number, b: number] & {
  __brand: 'SerializedColor3';
};

export namespace Color3SerializationUtils {
  function serialize(color3: Color3): SerializedColor3;
  function isSerializedColor3(value: unknown): value is SerializedColor3;
  function fromRGB(r: number, g: number, b: number): SerializedColor3;
  function deserialize(serializedColor3: SerializedColor3): Color3;
}
