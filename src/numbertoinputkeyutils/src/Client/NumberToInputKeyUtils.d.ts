export namespace NumberToInputKeyUtils {
  function getInputsForNumber(number: number): Enum.KeyCode[] | undefined;
  function getNumberFromKeyCode(keyCode: Enum.KeyCode): number | undefined;
  function getAllNumberKeyCodes(): Enum.KeyCode[];
}
