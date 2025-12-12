import { InputModeType } from '@quenty/inputmode';
import { InputKeyMapList } from './InputKeyMapList';

export namespace ProximityPromptInputUtils {
  function newInputKeyMapFromPrompt(prompt: ProximityPrompt): InputKeyMapList;
  function configurePromptFromInputKeyMap(
    prompt: ProximityPrompt,
    inputKeyMapList: InputKeyMapList
  ): void;
  function getFirstInputKeyCode(
    inputKeyMapList: InputKeyMapList,
    inputModeType: InputModeType
  ): Enum.KeyCode | undefined;
}
