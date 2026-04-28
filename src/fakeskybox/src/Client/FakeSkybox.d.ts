import { Signal } from '@quenty/signal';

interface Skybox {
  SkyboxUp: string;
  SkyboxDn: string;
  SkyboxLf: string;
  SkyboxRt: string;
  SkyboxFt: string;
  SkyboxBk: string;
}

interface FakeSkybox {
  VisibleChanged: Signal<[isVisible: boolean, doNotAnimate?: boolean]>;
  SetPartSize(size: number): this;
  Show(doNotAnimate?: boolean): this;
  Hide(doNotAnimate?: boolean): this;
  SetSkybox(skybox: Skybox): this;
  IsVisible(): boolean;
  UpdateRender(baseCFrame: CFrame): void;
  Destroy(): void;
}

interface FakeSkyboxConstructor {
  readonly ClassName: 'FakeSkybox';
  new (skybox: Skybox): FakeSkybox;
}

export const FakeSkybox: FakeSkyboxConstructor;
