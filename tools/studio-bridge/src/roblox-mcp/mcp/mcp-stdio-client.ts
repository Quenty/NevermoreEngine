import { spawn, type ChildProcessWithoutNullStreams } from 'child_process';
import { repairListResult } from './repair-list-result.js';

export const MCP_PROTOCOL_VERSION = '2025-06-18';

const DEFAULT_REQUEST_TIMEOUT_MS = 30_000;
const STDERR_TAIL_BYTES = 4096;
const CLOSE_TIMEOUT_MS = 2000;

export class McpTimeoutError extends Error {}

export interface McpTool {
  name: string;
  description?: string;
  inputSchema?: Record<string, unknown>;
}

export interface McpContent {
  type: string;
  text?: string;
  [key: string]: unknown;
}

export interface McpToolResult {
  isError: boolean;
  content: McpContent[];
  text: string;
}

export type SpawnMcpProcess = (
  command: string,
  args: string[]
) => ChildProcessWithoutNullStreams;

export interface McpStdioClientOptions {
  args?: string[];
  env?: Record<string, string>;
  spawnProcess?: SpawnMcpProcess;
  requestTimeoutMs?: number;
  clientInfo?: { name: string; version: string };
}

interface PendingRequest {
  method: string;
  resolve: (result: unknown) => void;
  reject: (err: Error) => void;
  timer: NodeJS.Timeout;
}

export class McpStdioClient {
  private _child: ChildProcessWithoutNullStreams;
  private _pending = new Map<number, PendingRequest>();
  private _nextId = 1;
  private _buffer = '';
  private _stderrTail = '';
  private _exitError: Error | undefined;
  private _exited = false;
  private _requestTimeoutMs: number;
  private _protocolVersion: string | undefined;
  private _serverInfo: { name?: string; version?: string } | undefined;

  private constructor(
    child: ChildProcessWithoutNullStreams,
    requestTimeoutMs: number
  ) {
    this._child = child;
    this._requestTimeoutMs = requestTimeoutMs;

    child.stdout.setEncoding('utf8');
    child.stdout.on('data', (chunk: string) => this._onStdout(chunk));
    child.stderr.setEncoding('utf8');
    child.stderr.on('data', (chunk: string) => {
      this._stderrTail = (this._stderrTail + chunk).slice(-STDERR_TAIL_BYTES);
    });
    child.stdin.on('error', () => {});
    child.unref?.();
    for (const stream of [child.stdin, child.stdout, child.stderr]) {
      (stream as { unref?: () => void }).unref?.();
    }
    child.on('error', (err) => this._fail(err));
    child.on('close', (code) => {
      this._exited = true;
      this._fail(
        new Error(
          `Studio's MCP server exited (code ${code ?? 'none'})${
            this._stderrTail.trim() ? `: ${this._stderrTail.trim()}` : ''
          }`
        )
      );
    });
  }

  static async startAsync(
    command: string,
    options: McpStdioClientOptions = {}
  ): Promise<McpStdioClient> {
    const spawnProcess: SpawnMcpProcess =
      options.spawnProcess ??
      ((cmd, args) =>
        spawn(cmd, args, {
          stdio: 'pipe',
          windowsHide: true,
          ...(options.env ? { env: options.env } : {}),
        }));
    const client = new McpStdioClient(
      spawnProcess(command, options.args ?? []),
      options.requestTimeoutMs ?? DEFAULT_REQUEST_TIMEOUT_MS
    );

    try {
      const result = (await client.requestAsync('initialize', {
        protocolVersion: MCP_PROTOCOL_VERSION,
        capabilities: {},
        clientInfo: options.clientInfo ?? {
          name: 'studio-bridge',
          version: '0.0.0',
        },
      })) as {
        protocolVersion?: string;
        serverInfo?: { name?: string; version?: string };
      };
      client._protocolVersion = result?.protocolVersion;
      client._serverInfo = result?.serverInfo;
      client._notify('notifications/initialized');
    } catch (err) {
      await client.closeAsync();
      throw err;
    }
    return client;
  }

  get protocolVersion(): string | undefined {
    return this._protocolVersion;
  }

  get serverInfo(): { name?: string; version?: string } | undefined {
    return this._serverInfo;
  }

  async listToolsAsync(): Promise<McpTool[]> {
    const result = (await this.requestAsync('tools/list', {})) as {
      tools?: McpTool[];
    };
    return Array.isArray(result?.tools) ? result.tools : [];
  }

  async callToolAsync(
    name: string,
    args: Record<string, unknown> = {},
    timeoutMs?: number
  ): Promise<McpToolResult> {
    const result = (await this.requestAsync(
      'tools/call',
      { name, arguments: args },
      timeoutMs
    )) as { isError?: boolean; content?: McpContent[] };
    const content = Array.isArray(result?.content) ? result.content : [];
    return {
      isError: result?.isError === true,
      content,
      text: content
        .filter((c) => c.type === 'text' && typeof c.text === 'string')
        .map((c) => c.text)
        .join('\n'),
    };
  }

  requestAsync(
    method: string,
    params: unknown,
    timeoutMs = this._requestTimeoutMs
  ): Promise<unknown> {
    if (this._exitError) {
      return Promise.reject(this._exitError);
    }
    const id = this._nextId++;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this._pending.delete(id);
        reject(new McpTimeoutError(`${method} timed out after ${timeoutMs}ms`));
      }, timeoutMs);
      this._pending.set(id, { method, resolve, reject, timer });
      this._write({ jsonrpc: '2.0', id, method, params });
    });
  }

  get isRunning(): boolean {
    return !this._exited;
  }

  async closeAsync(): Promise<void> {
    this._fail(new Error("Studio's MCP client was closed"));
    if (this._exited) {
      return;
    }
    let timer: NodeJS.Timeout | undefined;
    const exited = new Promise<void>((resolve) => {
      this._child.once('close', () => resolve());
      timer = setTimeout(resolve, CLOSE_TIMEOUT_MS);
    });
    this._child.stdin.end();
    this._child.kill();
    await exited;
    clearTimeout(timer);
  }

  private _notify(method: string, params?: unknown) {
    this._write({ jsonrpc: '2.0', method, ...(params ? { params } : {}) });
  }

  private _write(message: unknown) {
    this._child.stdin.write(JSON.stringify(message) + '\n');
  }

  private _onStdout(chunk: string) {
    this._buffer += chunk;
    let newline: number;
    while ((newline = this._buffer.indexOf('\n')) >= 0) {
      const line = this._buffer.slice(0, newline).trim();
      this._buffer = this._buffer.slice(newline + 1);
      if (line) {
        this._onLine(line);
      }
    }
  }

  private _onLine(line: string) {
    let message: {
      id?: unknown;
      result?: unknown;
      error?: { message?: string; code?: number };
    };
    try {
      message = JSON.parse(line);
    } catch {
      return;
    }
    if (typeof message?.id !== 'number') {
      return;
    }
    const pending = this._pending.get(message.id);
    if (!pending) {
      return;
    }
    this._pending.delete(message.id);
    clearTimeout(pending.timer);

    if (message.error) {
      pending.reject(
        new Error(
          `${pending.method} failed: ${
            message.error.message ?? `error ${message.error.code ?? ''}`
          }`.trim()
        )
      );
    } else {
      pending.resolve(repairListResult(message.result));
    }
  }

  private _fail(err: Error) {
    this._exitError ??= err;
    for (const pending of this._pending.values()) {
      clearTimeout(pending.timer);
      pending.reject(this._exitError);
    }
    this._pending.clear();
  }
}
