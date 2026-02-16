import * as Handlebars from 'handlebars';

/**
 * Substitute `{{VAR}}` placeholders in a template string using Handlebars.
 *
 * `noEscape` is set to true so that values containing `&`, `<`, etc. are
 * NOT HTML-escaped — critical when the template contains Lua source code.
 */
export function substituteTemplate(
  template: string,
  vars: Record<string, string>
): string {
  const compiled = (Handlebars as any).default.compile(template, {
    noEscape: true,
  });
  return compiled(vars);
}
