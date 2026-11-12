import { describe, expect, it } from 'vitest';
import {
  explainNoStudioAsync,
  type StudioSetup,
} from './explain-missing-session.js';

function setup(overrides: Partial<StudioSetup> = {}): StudioSetup {
  return {
    isRemote: false,
    listStudiosAsync: async () => [],
    isPluginInstalled: () => true,
    ...overrides,
  };
}

const runningStudio = { pid: 4242 } as any;

describe('explainNoStudioAsync', () => {
  it('says Studio is not open', async () => {
    expect(await explainNoStudioAsync(setup())).toMatchObject({
      code: 'NO_STUDIO_CONNECTED',
      message: "Roblox Studio isn't open.",
      fix: "Open a place in Studio, or run 'studio-bridge process launch'.",
    });
  });

  it('says the plugin is not installed when Studio is open without it', async () => {
    expect(
      await explainNoStudioAsync(
        setup({
          listStudiosAsync: async () => [runningStudio],
          isPluginInstalled: () => false,
        })
      )
    ).toMatchObject({
      message:
        "Studio is open, but the studio-bridge plugin isn't installed, so nothing connects to it.",
      fix: "Run 'studio-bridge plugin install'.",
    });
  });

  it('points at Manage Plugins when the plugin is installed but not connected', async () => {
    const err = await explainNoStudioAsync(
      setup({ listStudiosAsync: async () => [runningStudio] })
    );

    expect(err.message).toBe(
      "Studio is open, but the studio-bridge plugin hasn't connected."
    );
    expect(err.fix).toContain('Manage Plugins');
  });

  it("does not look at this machine's processes for a remote Studio", async () => {
    const err = await explainNoStudioAsync(
      setup({
        isRemote: true,
        listStudiosAsync: async () => {
          throw new Error('should not be called');
        },
      })
    );

    expect(err.message).toBe('No Studio is connected to studio-bridge.');
  });

  it('falls back to the general advice when processes cannot be listed', async () => {
    const err = await explainNoStudioAsync(
      setup({
        listStudiosAsync: async () => {
          throw new Error('tasklist failed');
        },
      })
    );

    expect(err.message).toBe('No Studio is connected to studio-bridge.');
  });
});
