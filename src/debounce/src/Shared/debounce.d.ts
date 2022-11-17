declare function debounce<T extends Array<any>>(
	timeoutInSeconds: number,
	func: (...args: T) => void
): (...args: T) => void;
export = debounce;
