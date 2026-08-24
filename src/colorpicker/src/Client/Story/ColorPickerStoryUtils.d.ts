import { Maid } from '@quenty/maid';
import { ValueObject } from '@quenty/valueobject';
import { HSVColorPicker } from '../HSV/HSVColorPicker';
import { Blend } from '@quenty/blend';

export namespace ColorPickerStoryUtils {
  function createPicker(
    maid: Maid,
    valueSync: Color3Value,
    labelText: string,
    currentVisible: ValueObject<HSVColorPicker | undefined>
  ): ReturnType<typeof Blend.New<'ImageButton'>>;
  function create(
    maid: Maid,
    buildPickers: (
      callback: (labelText: string, valueSync: Color3Value) => void
    ) => void
  ): ReturnType<typeof Blend.New<'Frame'>>;
}
