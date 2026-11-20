import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import * as fs from 'fs';
import * as os from 'os';
import * as path from 'path';
import { OutputHelper } from '@quenty/cli-output-helpers';
import { TemplateHelper } from './template-helpers.js';

describe('TemplateHelper.camelize', () => {
  it('leaves an already upper camel case name alone', () => {
    expect(TemplateHelper.camelize('MyPackage')).toBe('MyPackage');
    expect(TemplateHelper.camelize('AdorneeEditorWelding')).toBe(
      'AdorneeEditorWelding'
    );
  });

  it('upper cases the first letter of a lower case name', () => {
    expect(TemplateHelper.camelize('area')).toBe('Area');
  });

  it('joins hyphenated names into a valid Luau identifier', () => {
    expect(TemplateHelper.camelize('adornee-editor-welding')).toBe(
      'AdorneeEditorWelding'
    );
    expect(TemplateHelper.camelize('nevermore-test-runner')).toBe(
      'NevermoreTestRunner'
    );
  });

  it('joins underscored and spaced names', () => {
    expect(TemplateHelper.camelize('adornee_editor_welding')).toBe(
      'AdorneeEditorWelding'
    );
    expect(TemplateHelper.camelize('adornee editor welding')).toBe(
      'AdorneeEditorWelding'
    );
  });

  it('keeps casing inside a part, so an acronym survives', () => {
    expect(TemplateHelper.camelize('influxdb-service')).toBe('InfluxdbService');
    expect(TemplateHelper.camelize('InfluxDB-service')).toBe('InfluxDBService');
  });

  it('ignores repeated, leading and trailing separators', () => {
    expect(TemplateHelper.camelize('-adornee--editor_ welding-')).toBe(
      'AdorneeEditorWelding'
    );
  });

  it('handles digits in a name', () => {
    expect(TemplateHelper.camelize('egg-hunt-2026')).toBe('EggHunt2026');
  });

  it('returns an empty string for a name with nothing in it', () => {
    expect(TemplateHelper.camelize('')).toBe('');
    expect(TemplateHelper.camelize('  -_ ')).toBe('');
  });
});

describe('TemplateHelper.toPackageName', () => {
  it('lower cases the name', () => {
    expect(TemplateHelper.toPackageName('MyPackage')).toBe('mypackage');
  });

  it('keeps hyphens, so the npm and Rojo name stays readable', () => {
    expect(TemplateHelper.toPackageName('adornee-editor-welding')).toBe(
      'adornee-editor-welding'
    );
    expect(TemplateHelper.toPackageName('Adornee-Editor-Welding')).toBe(
      'adornee-editor-welding'
    );
  });

  it('drops whitespace', () => {
    expect(TemplateHelper.toPackageName('my package')).toBe('mypackage');
    expect(TemplateHelper.toPackageName('  spaced  out  ')).toBe('spacedout');
  });

  it('leaves an already conventional package name alone', () => {
    expect(TemplateHelper.toPackageName('adorneeutils')).toBe('adorneeutils');
  });
});

describe('TemplateHelper.toIndexExpression', () => {
  it('uses a dot access for a name that is a valid Luau identifier', () => {
    expect(TemplateHelper.toIndexExpression('adorneeutils')).toBe(
      '.adorneeutils'
    );
    expect(TemplateHelper.toIndexExpression('MyPackage')).toBe('.MyPackage');
    expect(TemplateHelper.toIndexExpression('_private')).toBe('._private');
    expect(TemplateHelper.toIndexExpression('area2')).toBe('.area2');
  });

  it('brackets a hyphenated name, which cannot be dot accessed', () => {
    expect(TemplateHelper.toIndexExpression('adornee-editor-welding')).toBe(
      '["adornee-editor-welding"]'
    );
  });

  it('brackets a name that does not start with a letter', () => {
    expect(TemplateHelper.toIndexExpression('2026-egg-hunt')).toBe(
      '["2026-egg-hunt"]'
    );
  });

  it('brackets a name that is a Luau keyword', () => {
    expect(TemplateHelper.toIndexExpression('end')).toBe('["end"]');
    expect(TemplateHelper.toIndexExpression('function')).toBe('["function"]');
    expect(TemplateHelper.toIndexExpression('nil')).toBe('["nil"]');
  });

  it('does not treat a keyword prefix as a keyword', () => {
    expect(TemplateHelper.toIndexExpression('ending')).toBe('.ending');
  });

  it('brackets an empty name rather than emitting a bare dot', () => {
    expect(TemplateHelper.toIndexExpression('')).toBe('[""]');
  });
});

describe('name derivation together', () => {
  it('gives a hyphenated package a hyphenated name and a camel identifier', () => {
    const raw = 'adornee-editor-welding';

    expect(TemplateHelper.toPackageName(raw)).toBe('adornee-editor-welding');
    expect(TemplateHelper.camelize(raw)).toBe('AdorneeEditorWelding');
  });

  it('matches what existing packages are already named', () => {
    expect(TemplateHelper.toPackageName('adornee-editor-placement')).toBe(
      'adornee-editor-placement'
    );
    expect(TemplateHelper.camelize('adornee-editor-placement')).toBe(
      'AdorneeEditorPlacement'
    );
  });
});

describe('TemplateHelper.createDirectoryContentsAsync', () => {
  let templateDir: string;
  let targetDir: string;

  beforeEach(async () => {
    templateDir = await fs.promises.mkdtemp(path.join(os.tmpdir(), 'tpl-'));
    targetDir = await fs.promises.mkdtemp(path.join(os.tmpdir(), 'target-'));

    await fs.promises.writeFile(
      path.join(templateDir, 'package.json'),
      '{"name": "{{packageName}}"}'
    );
    await fs.promises.mkdir(path.join(templateDir, 'src'));
    await fs.promises.writeFile(
      path.join(templateDir, 'src', '{{packageNameProper}}Utils.lua'),
      '-- {{packageNameProper}}'
    );
  });

  afterEach(async () => {
    await fs.promises.rm(templateDir, { recursive: true, force: true });
    await fs.promises.rm(targetDir, { recursive: true, force: true });
  });

  const input = { packageName: 'spring', packageNameProper: 'Spring' };

  it('writes every template file into an empty folder', async () => {
    await TemplateHelper.createDirectoryContentsAsync(
      templateDir,
      targetDir,
      input,
      false
    );

    expect(
      await fs.promises.readFile(path.join(targetDir, 'package.json'), 'utf8')
    ).toBe('{"name": "spring"}');
    expect(
      await fs.promises.readFile(
        path.join(targetDir, 'src', 'SpringUtils.lua'),
        'utf8'
      )
    ).toBe('-- Spring');
  });

  it('fills in missing files without overwriting existing ones', async () => {
    await fs.promises.writeFile(
      path.join(targetDir, 'package.json'),
      'existing'
    );

    await TemplateHelper.createDirectoryContentsAsync(
      templateDir,
      targetDir,
      input,
      false
    );

    expect(
      await fs.promises.readFile(path.join(targetDir, 'package.json'), 'utf8')
    ).toBe('existing');
    expect(fs.existsSync(path.join(targetDir, 'src', 'SpringUtils.lua'))).toBe(
      true
    );
  });

  it('reports existing files as skipped, not written, on a dryrun', async () => {
    await fs.promises.writeFile(
      path.join(targetDir, 'package.json'),
      'existing'
    );
    const infoSpy = vi.spyOn(OutputHelper, 'info').mockImplementation(() => {});
    const logSpy = vi.spyOn(console, 'log').mockImplementation(() => {});

    try {
      await TemplateHelper.createDirectoryContentsAsync(
        templateDir,
        targetDir,
        input,
        true
      );

      const messages = infoSpy.mock.calls.map((call) => String(call[0]));
      const existingPath = path.join(targetDir, 'package.json');
      const newPath = path.join(targetDir, 'src', 'SpringUtils.lua');

      expect(messages).toContain(
        `[DRYRUN]: Skip existing file ${existingPath}`
      );
      expect(messages).not.toContain(`[DRYRUN]: Write file ${existingPath}`);
      expect(messages).toContain(`[DRYRUN]: Write file ${newPath}`);
      expect(fs.existsSync(path.join(targetDir, 'src'))).toBe(false);
    } finally {
      infoSpy.mockRestore();
      logSpy.mockRestore();
    }
  });
});
