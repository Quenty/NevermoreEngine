import { ServiceBag } from '@quenty/servicebag';
import { Flipbook } from '../Flipbook';

interface FlipbookLibrary {
  Init(serviceBag: ServiceBag): void;
  GetPreloadAssetIds(): string[];
  GetFlipbook(
    flipbookName: string,
    theme?: 'Light' | 'Dark'
  ): Flipbook | undefined;
  Register(
    flipbookName: string,
    theme: 'Light' | 'Dark',
    flipbook: Flipbook
  ): void;
}

interface FlipbookLibraryConstructor {
  readonly ClassName: 'FlipbookLibrary';
  new (
    serviceName: string,
    register: (this: FlipbookLibrary) => void
  ): FlipbookLibrary;
}

export const FlipbookLibrary: FlipbookLibraryConstructor;
