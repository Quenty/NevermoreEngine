import { Observable } from '@quenty/rx';

interface CoreGuiEnabler {
  IsEnabled(state: string | Enum.CoreGuiType): boolean;
  ObserveIsEnabled(state: string | Enum.CoreGuiType): Observable<boolean>;
  AddState(
    state: string | Enum.CoreGuiType,
    onChangeCallback: (isEnabled: boolean) => void
  ): void;
  Disable(state: string | Enum.CoreGuiType): void;
  PushDisable(state: string | Enum.CoreGuiType): void;
  Enable(key: unknown, state: string | Enum.CoreGuiType): void;
}

interface CoreGuiEnablerConstructor {
  readonly ClassName: 'CoreGuiEnabler';
  new (): CoreGuiEnabler;
}

export const CoreGuiEnabler: CoreGuiEnablerConstructor;
