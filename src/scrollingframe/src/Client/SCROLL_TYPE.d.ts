export interface ScrollType {
  Direction: 'x' | 'y';
}

export const SCROLL_TYPE: Readonly<{
  Horizontal: {
    Direction: 'x';
  };
  Vertical: {
    Direction: 'y';
  };
}>;
