import { Promise } from '@quenty/promise';
import { RobloxApiDumpData } from './RobloxApiDump';

export interface RobloxApiEnumData {
  Name: string;
  Items: {
    Name: string;
    Value: number;
  }[];
}

export namespace RobloxApiUtils {
  function promiseDump(): Promise<RobloxApiDumpData>;
}
