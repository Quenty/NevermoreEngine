import { BaseObject } from '@quenty/baseobject';
import { ToPropertyObservableArgument } from '@quenty/blend';
import { Observable } from '@quenty/rx';

interface RadialImage extends BaseObject {
  Gui: Frame;
  SetImage(image: string): void;
  SetPercent(percent: number): void;
  SetTransparency(transparency: number): void;
  SetEnabledTransparency(transparency: number): void;
  SetDisabledTransparency(transparency: number): void;
  SetEnabledColor(color: Color3): void;
  SetDisabledColor(color: Color3): void;
}

interface RadialImageConstructor {
  readonly ClassName: 'RadialImage';
  new (): RadialImage;

  blend: (props: {
    Image?: string | ToPropertyObservableArgument<string>;
    Percent?: number | ToPropertyObservableArgument<number>;
    EnabledTransparency?: number | ToPropertyObservableArgument<number>;
    DisabledTransparency?: number | ToPropertyObservableArgument<number>;
    EnabledColor?: Color3 | ToPropertyObservableArgument<Color3>;
    DisabledColor?: Color3 | ToPropertyObservableArgument<Color3>;
    Transparency?: number | ToPropertyObservableArgument<number>;
    Size?: UDim2 | ToPropertyObservableArgument<UDim2>;
    Position?: UDim2 | ToPropertyObservableArgument<UDim2>;
    AnchorPoint?: Vector2 | ToPropertyObservableArgument<Vector2>;
  }) => Observable<Frame>;
}

export const RadialImage: RadialImageConstructor;
