import { BaseObject } from '@quenty/baseobject';
import { ServiceBag } from '@quenty/servicebag';
import { Motor6DTransformer } from '../Animation/Motor6DTransformer';

interface Motor6DStackBase extends BaseObject {
  TransformFromCFrame(physicsTransformCFrame: CFrame, speed?: number): void;
  Push(transformer: Motor6DTransformer): () => void;
}

interface Motor6DStackBaseConstructor {
  readonly ClassName: 'Motor6DStackBase';
  new (motor6D: Motor6D, serviceBag: ServiceBag): Motor6DStackBase;
}

export const Motor6DStackBase: Motor6DStackBaseConstructor;
