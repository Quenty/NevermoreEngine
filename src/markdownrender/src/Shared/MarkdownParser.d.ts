export type ParsedMarkdown = (
  | string
  | (
      | {
          Type: 'List';
          Level: number;
        }
      | {
          Type: 'Header';
          Level: number;
          Text: string;
        }
    )
)[];

interface MarkdownParser {
  GetLines(): void;
  ParseList(oldLines: ParsedMarkdown): ParsedMarkdown;
  ParseHeaders(oldLines: ParsedMarkdown): ParsedMarkdown;
  ParseParagraphs(oldLines: ParsedMarkdown): ParsedMarkdown;
  Parse(): ParsedMarkdown;
}

interface MarkdownParserConstructor {
  readonly ClassName: 'MarkdownParser';
  new (text: string): MarkdownParser;
}

export const MarkdownParser: MarkdownParserConstructor;
