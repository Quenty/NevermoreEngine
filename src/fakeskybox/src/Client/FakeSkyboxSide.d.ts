interface FakeSkyboxSide {
  SetPartSize(partSize: number): this;
  UpdateSizing(): void;
  SetImage(image: string): this;
  SetTransparency(transparency: number): this;
  UpdateRender(relativeCFrame: CFrame): void;
}

interface FakeSkyboxSideConstructor {
  readonly ClassName: 'FakeSkyboxSide';
  new (partSize: number, normal: Vector3, parent: Instance): FakeSkyboxSide;

  CanvasSize: 1024;
  PartWidth: 1;
}

export const FakeSkyboxSide: FakeSkyboxSideConstructor;
