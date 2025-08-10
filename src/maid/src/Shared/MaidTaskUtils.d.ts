import { MaidTask } from "./Maid";

export declare const isValidTask: (job: any) => boolean;
export declare const doTask: (job: MaidTask) => void;
export declare const delayed: (time: number, job: MaidTask) => (() => void)