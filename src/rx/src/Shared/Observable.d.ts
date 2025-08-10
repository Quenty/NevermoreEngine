import { MaidTask } from "../../../maid";
import { Subscription } from "./Subscription";

type Observable<T extends unknown[] = unknown[]> = {
	Subscribe(): Subscription<T>;
	Pipe<U extends unknown[]>(
		...operators: ((subscription: Subscription<T>) => Subscription<U>)[]
	): Observable<U>;
	Subscribe(
		fireCallback?: (...args: T) => void,
		failCallback?: () => void,
		completeCallback?: () => void
	): Subscription<T>;
}

declare interface ObservableConstructor {
	readonly ClassName: "Observable";
	new <T extends unknown[]>(onSubscribe: (subscription: Subscription<T>) => MaidTask): Observable<T>;

	isObservable: (item: any) => item is Observable;
}

export declare const Observable: ObservableConstructor;