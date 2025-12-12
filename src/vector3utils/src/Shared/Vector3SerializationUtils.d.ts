export type SerializedVector3 = [x: number, y: number, z: number] & {
  __brand: 'SerializedVector3';
};

export namespace Vector3SerializationUtils {
  function isSerializedVector3(value: unknown): value is SerializedVector3;
  function serialize(vector3: Vector3): SerializedVector3;
  function deserialize(serializedVector3: SerializedVector3): Vector3;
}
