/**
 * Global arguments available to all studio-bridge commands.
 */
export interface StudioBridgeGlobalArgs {
  verbose: boolean;
  place?: string;
  timeout: number;
  logs: boolean;
  remote?: string;
  local?: boolean;
}
