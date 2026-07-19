import { ParsedMarkdown } from './MarkdownParser';

export interface MarkdownRenderOptions {
  TextSize: number;
  SpaceAfterParagraph: number;
}

interface MarkdownRender {
  WithOptions(options: MarkdownRenderOptions): this;
  Render(data: ParsedMarkdown): void;
}

interface MarkdownRenderConstructor {
  readonly ClassName: 'MarkdownRender';
  new (gui: GuiObject, width: number): MarkdownRender;

  SpaceAfterParagraph: 10;
  SpaceAfterHeader: 5;
  SpaceBetweenList: 2;
  TextSize: 18;
  Indent: 30;
  TextColor3: Color3;
  MaxHeaderLevel: 3;
}

export const MarkdownRender: MarkdownRenderConstructor;
