import { EventEmitter } from 'events';
import { PassThrough } from 'stream';
import type { ChildProcessWithoutNullStreams } from 'child_process';

export type FakeHandler = (
  method: string,
  params: any
) =>
  | { result?: unknown; error?: { code: number; message: string } }
  | undefined;

export interface FakeMcpServer {
  child: ChildProcessWithoutNullStreams;
  requests: Array<{ method: string; params: any }>;
  exit(code: number, stderr?: string): void;
}

export function createFakeMcpServer(handler: FakeHandler): FakeMcpServer {
  const stdin = new PassThrough();
  const stdout = new PassThrough();
  const stderr = new PassThrough();
  const child = Object.assign(new EventEmitter(), {
    stdin,
    stdout,
    stderr,
    exitCode: null as number | null,
    killed: false,
    kill() {
      child.killed = true;
      child.emit('close', null);
      return true;
    },
  });
  const requests: FakeMcpServer['requests'] = [];

  let buffer = '';
  stdin.setEncoding('utf8');
  stdin.on('data', (chunk: string) => {
    buffer += chunk;
    let newline: number;
    while ((newline = buffer.indexOf('\n')) >= 0) {
      const message = JSON.parse(buffer.slice(0, newline));
      buffer = buffer.slice(newline + 1);
      requests.push({ method: message.method, params: message.params });
      if (message.id === undefined) {
        continue;
      }
      const reply = handler(message.method, message.params);
      if (reply) {
        stdout.write(
          JSON.stringify({ jsonrpc: '2.0', id: message.id, ...reply }) + '\n'
        );
      }
    }
  });

  return {
    child: child as unknown as ChildProcessWithoutNullStreams,
    requests,
    exit(code, text) {
      if (text) {
        stderr.write(text);
      }
      setImmediate(() => {
        child.exitCode = code;
        child.emit('close', code);
      });
    },
  };
}

export function toolText(text: string, isError = false) {
  return { result: { content: [{ type: 'text', text }], isError } };
}
