import { BaseObject } from '@quenty/baseobject';
import { Brio } from '@quenty/brio';
import { Observable } from '@quenty/rx';
import { Signal } from '@quenty/signal';
import { ValueObject } from '@quenty/valueobject';

interface FontPalette extends BaseObject {
  FontAdded: Signal<string>;
  GetFontNames(): string[];
  ObserveFontNames(): Observable<string>;
  ObserveFontNamesBrio(): Observable<Brio<string>>;
  GetFont(fontName: string): Enum.Font;
  ObserveFont(fontName: string): Observable<Enum.Font>;
  ObserveFontFace(
    fontName: string,
    weight?: Enum.FontWeight | Observable<Enum.FontWeight>,
    style?: Enum.FontStyle | Observable<Enum.FontStyle>
  ): Observable<Font>;
  GetFontFaceValue(fontName: string): ValueObject<Font>;
  GetFontValue(fontName: string): ValueObject<Enum.Font>;
  GetDefaultFontMap(): Record<string, Font | Enum.Font>;
  DefineFont(
    fontName: string,
    defaultFont: Enum.Font | Font
  ): ValueObject<Enum.Font> | undefined;
}

interface FontPaletteConstructor {
  readonly ClassName: 'FontPalette';
  new (): FontPalette;
}

export const FontPalette: FontPaletteConstructor;
