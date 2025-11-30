export namespace InputObjectUtils {
  function isMouseUserInputType(
    userInputType: Enum.UserInputType
  ): userInputType is
    | Enum.UserInputType.MouseButton1
    | Enum.UserInputType.MouseButton2
    | Enum.UserInputType.MouseButton3
    | Enum.UserInputType.MouseWheel
    | Enum.UserInputType.MouseMovement;
  function isMouseButtonInputType(
    userInputType: Enum.UserInputType
  ): userInputType is
    | Enum.UserInputType.MouseButton1
    | Enum.UserInputType.MouseButton2
    | Enum.UserInputType.MouseButton3;
  function isSameInputObject(
    inputObject1: InputObject,
    inputObject2: InputObject
  ): boolean;
}
