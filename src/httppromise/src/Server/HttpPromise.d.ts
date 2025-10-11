import { Promise } from '@quenty/promise';

export namespace HttpPromise {
  function request(request: Request): Promise<RequestAsyncResponse>;
  function isHttpResponse(value: unknown): value is RequestAsyncResponse;
  function convertHttpResponseToString(value: RequestAsyncResponse): string;
  function json(request: RequestAsyncResponse | string): Promise;
  function logFailedRequests(requests: (string | RequestAsyncResponse)[]): void;
  function decodeJSON(response: RequestAsyncResponse): unknown;
}
