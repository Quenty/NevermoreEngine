import { MaidTask } from './Maid';

export namespace MaidTaskUtils {
  function isValidTask(job: unknown): job is MaidTask;
  function doTask(job: MaidTask): void;
  function delayed(time: number, job: MaidTask): () => void;
}
