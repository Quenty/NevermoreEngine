type OnlyPropertiesOfType<O, T> = {
  [K in keyof O as O[K] extends T ? K : never]: O[K];
};

export namespace qGUI {
  function PointInBounds(frame: Frame, x: number, y: number): boolean;
  function MouseOver(mouse: Mouse, frame: Frame): boolean;
  function TweenTransparency<T extends GuiBase>(
    gui: T,
    newProperties: Partial<
      OnlyPropertiesOfType<WritableInstanceProperties<T>, number>
    >,
    duration: number
  ): void;
  function StopTransparencyTween(gui: GuiBase): void;
  function TweenColor3<T extends GuiBase>(
    gui: T,
    newProperties: Partial<
      OnlyPropertiesOfType<WritableInstanceProperties<T>, Color3>
    >,
    duration: number
  ): void;
  function StopColor3Tween(gui: GuiBase): void;
  function AddTexturedWindowTemplate<
    T extends keyof CreatableInstances = 'Frame'
  >(
    frame: Frame,
    radius: number,
    type?: T
  ): LuaTuple<
    [
      topLeft: Instances[T],
      topRight: Instances[T],
      bottomLeft: Instances[T],
      bottomRight: Instances[T],
      middle: Instances[T],
      middleLeft: Instances[T],
      middleRight: Instances[T]
    ]
  >;
  function AddNinePatch<T extends 'ImageLabel' | 'ImageButton' = 'ImageLabel'>(
    frame: Frame,
    image: string,
    imageSize: Vector2,
    radius: number,
    type?: T,
    properties?: Partial<InstanceProperties<Instances[T]>>
  ): LuaTuple<
    [
      ...ReturnType<typeof AddTexturedWindowTemplate<T>>,
      middleTop: Instances[T],
      middleBottom: Instances[T]
    ]
  >;
  function BackWithRoundedRectangle(
    frame: Frame,
    radius: number,
    color?: Color3
  ): ReturnType<typeof AddNinePatch<'ImageLabel'>>;
}
