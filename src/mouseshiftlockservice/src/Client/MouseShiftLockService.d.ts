export interface MouseShiftLockService {
  readonly ServiceName: 'MouseShiftLockService';
  Init(): void;
  EnableShiftLock(): void;
  DisableShiftLock(): void;
}
