import { MaidTask } from './Maid';

export namespace MaidTaskUtils {
  function isValidTask(job: any): boolean;
  function doTask(job: MaidTask): void;
  function delayed(time: number, job: MaidTask): () => void;
}
