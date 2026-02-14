/**
 * Generates a minimal `.rbxmx` XML model file wrapping a Lua source string as
 * a Script (plugin). The format is intentionally simple — no XML library
 * needed, just string concatenation with CDATA escaping.
 */

/**
 * Escape a Lua source string for embedding inside a CDATA section.
 *
 * CDATA sections cannot contain the literal sequence `]]>`. If the source
 * includes it we split the CDATA section around the occurrence.
 */
function escapeCdata(source: string): string {
  // Split on `]]>` and rejoin with the standard CDATA-split trick:
  //   ]]]]><![CDATA[>
  return source.replace(/\]\]>/g, ']]]]><![CDATA[>');
}

export interface RbxmxOptions {
  /** Name of the Script instance */
  name: string;
  /** Lua source code */
  source: string;
}

/**
 * Build a .rbxmx XML string containing a single Script instance with the
 * given source code.
 */
export function buildRbxmx(options: RbxmxOptions): string {
  const { name, source } = options;
  return [
    '<roblox version="4">',
    '  <Item class="Script" referent="0">',
    '    <Properties>',
    `      <string name="Name">${name}</string>`,
    `      <ProtectedString name="Source"><![CDATA[${escapeCdata(source)}]]></ProtectedString>`,
    '    </Properties>',
    '  </Item>',
    '</roblox>',
  ].join('\n');
}
