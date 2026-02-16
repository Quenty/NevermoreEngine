/**
 * Terminal mode for studio-bridge — keeps Studio alive and provides
 * an interactive REPL for executing Luau scripts repeatedly.
 */

import * as fs from 'fs/promises';
import * as path from 'path';
import { OutputHelper } from '@quenty/cli-output-helpers';
import {
  StudioBridgeServer,
  type StudioBridgePhase,
} from '../server/studio-bridge-server.js';
import { TerminalEditor } from './terminal-editor.js';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface TerminalModeOptions {
  placePath?: string;
  scriptPath?: string;
  scriptText?: string;
  timeoutMs: number;
  verbose: boolean;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const DIM = '\x1b[2m';
const RED = '\x1b[31m';
const YELLOW = '\x1b[33m';
const CYAN = '\x1b[36m';
const RESET = '\x1b[0m';

function printSubmittedCode(code: string): void {
  const lines = code.split('\n');
  for (let i = 0; i < lines.length; i++) {
    const prefix = i === 0 ? `${CYAN}\u276F${RESET} ` : '  ';
    console.log(`${prefix}${DIM}${lines[i]}${RESET}`);
  }
}

function printOutput(level: string, body: string): void {
  // Filter internal plugin messages
  if (body.startsWith('[StudioBridge]')) return;

  switch (level) {
    case 'Warning':
      console.log(`${YELLOW}${body}${RESET}`);
      break;
    case 'Error':
      console.log(`${RED}${body}${RESET}`);
      break;
    default:
      console.log(body);
      break;
  }
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

export async function runTerminalMode(
  options: TerminalModeOptions
): Promise<void> {
  const { placePath, timeoutMs, verbose } = options;

  OutputHelper.setVerbose(verbose);

  // Phase progress — single line that updates in place
  const phaseLabels: Record<string, string> = {
    building: 'Building place...',
    launching: 'Launching Studio...',
    connecting: 'Waiting for plugin...',
  };

  const server = new StudioBridgeServer({
    placePath,
    timeoutMs,
    onPhase: (phase: StudioBridgePhase) => {
      const label = phaseLabels[phase];
      if (label) {
        process.stdout.write(`\r\x1b[2K${DIM}${label}${RESET}`);
      }
    },
  });

  // Start the bridge
  try {
    await server.startAsync();
  } catch (err) {
    process.stdout.write(`\r\x1b[2K`);
    OutputHelper.error(
      `Failed to start: ${err instanceof Error ? err.message : String(err)}`
    );
    process.exit(1);
  }

  process.stdout.write(`\r\x1b[2K${DIM}Studio connected.${RESET}\n\n`);

  // Run initial script if provided
  if (options.scriptPath || options.scriptText) {
    let initialScript: string;
    if (options.scriptText) {
      initialScript = options.scriptText;
    } else {
      const resolved = path.resolve(options.scriptPath!);
      try {
        initialScript = await fs.readFile(resolved, 'utf-8');
      } catch {
        OutputHelper.error(`Could not read script file: ${resolved}`);
        await server.stopAsync();
        process.exit(1);
      }
    }

    await executeAndPrint(server, initialScript, timeoutMs);
    console.log('');
  }

  // Enter REPL
  const editor = new TerminalEditor();

  const cleanup = async () => {
    editor.stop();
    console.log(`${DIM}Shutting down...${RESET}`);
    await server.stopAsync();
    process.exit(0);
  };

  editor.on('exit', () => {
    cleanup();
  });

  editor.on('submit', async (buffer: string) => {
    printSubmittedCode(buffer);
    try {
      await executeAndPrint(server, buffer, timeoutMs);
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      if (
        msg.includes('no connected client') ||
        msg.includes("expected state 'ready'")
      ) {
        console.log(
          `\n${RED}Studio disconnected.${RESET}`
        );
        editor.stop();
        await server.stopAsync();
        process.exit(1);
      }
      console.log(`${RED}Error: ${msg}${RESET}`);
    }
    console.log('');
    editor._render();
  });

  editor.start();
}

async function executeAndPrint(
  server: StudioBridgeServer,
  script: string,
  timeoutMs: number
): Promise<void> {
  const result = await server.executeAsync({
    scriptContent: script,
    timeoutMs,
    onOutput: (level, body) => printOutput(level, body),
  });

  if (!result.success && result.logs) {
    // Print any error info not already printed via onOutput
    const lines = result.logs.split('\n');
    for (const line of lines) {
      if (line.startsWith('[StudioBridge]')) {
        console.log(`${RED}${line}${RESET}`);
      }
    }
  }
}
