import { Signal, SignalLike } from '@quenty/signal';
import { ToPropertyObservableArgument } from './Blend';
import { Observable } from '@quenty/rx';
import { Promise } from '@quenty/promise';
import { SpringClock } from '@quenty/spring';

interface SpringObject<T> {
  Changed: Signal;
  Observe(): Observable<T>;
  ObserveRenderStepped(): Observable<T>;
  ObserveTarget(): Observable<T>;
  ObserveVelocityOnRenderStepped(): Observable<T>;
  PromiseFinished(signal?: SignalLike): Promise;
  ObserveVelocityOnSignal(signal: SignalLike): Observable<T>;
  ObserveOnSignal(signal: SignalLike): Observable<T>;
  IsAnimating(): boolean;
  Impulse(velocity: T): void;
  SetTarget(target: T, doNotAnimate?: boolean): () => void;
  SetVelocity(velocity: T): void;
  SetPosition(position: T): void;
  SetDamper(damper: number | ToPropertyObservableArgument<number>): void;
  SetSpeed(speed: number | ToPropertyObservableArgument<number>): void;
  SetClock(clock: SpringClock): void;
  SetEpsilon(epsilon: number): void;
  TimeSkip(delta: number): void;
  Destroy(): void;

  Value: T;
  Position: T;
  p: T;
  Velocity: T;
  v: T;
  Target: T;
  t: T;
  get Damper(): number;
  set Damper(value: number | ToPropertyObservableArgument<number>);
  get d(): number;
  set d(value: number | ToPropertyObservableArgument<number>);
  get Speed(): number;
  set Speed(value: number | ToPropertyObservableArgument<number>);
  get s(): number;
  set s(value: number | ToPropertyObservableArgument<number>);
  Clock: SpringClock;
  Epsilon: number;
}

interface SpringObjectConstructor {
  readonly ClassName: 'SpringObject';
  new (): SpringObject<number>;
  new <T>(
    value: T,
    speed?: number | ToPropertyObservableArgument<number>,
    damper?: number | ToPropertyObservableArgument<number>
  ): SpringObject<T>;
}

export const SpringObject: SpringObjectConstructor;
