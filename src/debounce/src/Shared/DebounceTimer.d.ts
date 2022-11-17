declare class DebounceTimer {
	constructor(length: number);
	SetLength(length: number): void;
	Restart(): void;
	IsRunning(): boolean;
	IsDone(): boolean;
}
export = DebounceTimer;
