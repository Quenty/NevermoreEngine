export namespace LipsumUtils {
  function username(random?: Random): string;
  function word(random?: Random): string;
  function words(numWords: number, random?: Random): string;
  function sentence(numWords?: number, random?: Random): string;
  function paragraph(
    numSentences?: number,
    createSentence?: () => string,
    random?: Random
  ): string;
  function document(
    numParagraphs?: number,
    createParagraph?: () => string,
    random?: Random
  ): string;
}
