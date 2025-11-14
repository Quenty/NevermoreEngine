import { Promise } from '@quenty/promise';
import { Observable } from '@quenty/rx';

export namespace TextServiceUtils {
  function getSizeForLabel(
    textLabel: TextLabel,
    text: string,
    maxWidth?: number
  ): Vector2;
  function promiseTextBounds(params: GetTextBoundsParams): Promise<Vector2>;
  function observeSizeForLabelProps(
    props: {
      Text: string | ValueBase;
      TextSize: number;
      MaxSize?: Vector2;
      LineHeight?: number;
    } & (
      | {
          Font: Enum.Font;
        }
      | {
          FontFace: Font;
        }
      | {
          Font: Enum.Font;
          FontFace: Font;
        }
    )
  ): Observable<Vector2>;
}
