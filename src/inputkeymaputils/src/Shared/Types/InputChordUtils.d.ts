export interface ModifierInputChord {
  type: 'ModifierInputChord';
  modifiers: Enum.KeyCode[];
  keyCode: Enum.KeyCode;
}

export namespace InputChordUtils {
  function isModifierInputChord(value: unknown): value is ModifierInputChord;
  function createModifierInputChord(
    modifiers: Enum.KeyCode[],
    keyCode: Enum.KeyCode
  ): ModifierInputChord;
}
