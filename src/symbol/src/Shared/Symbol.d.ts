interface Symbol {}

interface SymbolConstructor {
  named: (name: string) => Symbol;
  isSymbol: (value: unknown) => value is Symbol;
}

export const Symbol: SymbolConstructor;
