interface BaseObject {
  Destroy(): void;
}

interface BaseObjectConstructor {
  readonly ClassName: 'BaseObject';
  new (instance?: Instance): BaseObject;
}

export const BaseObject: BaseObjectConstructor;
