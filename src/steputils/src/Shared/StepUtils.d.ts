import { SignalLike } from '@quenty/signal';

export namespace StepUtils {
  function bindToRenderStep(update: () => boolean): () => void;
  function deferWait(): void;
  function bindToStepped(update: () => boolean): () => void;
  function bindToSignal(signal: SignalLike, update: () => boolean): () => void;
  function onceAtRenderPriority(priority: number, func: () => void): () => void;
  function onceAtStepped(func: () => void): () => void;
  function onceAtRenderStepped(func: () => void): () => void;
  function onceAtEvent(event: SignalLike, func: () => void): () => void;
}
