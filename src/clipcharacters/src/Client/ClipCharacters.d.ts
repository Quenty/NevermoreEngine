import { BaseObject } from '@quenty/baseobject';

interface ClipCharacters extends BaseObject {}

interface ClipCharactersConstructor {
  readonly ClassName: 'ClipCharacters';
  new (): ClipCharacters;
}

export const ClipCharacters: ClipCharactersConstructor;
