import { MaidTask } from './Maid';

export const isValidTask: (job: any) => boolean;
export const doTask: (job: MaidTask) => void;
export const delayed: (time: number, job: MaidTask) => () => void;
