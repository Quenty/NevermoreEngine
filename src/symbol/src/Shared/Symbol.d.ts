interface Symbol {}

interface SymbolConstructor {
  named: (name: string) => Symbol;
  isSymbol: (value: any) => value is Symbol;
}

export const Symbol: SymbolConstructor;
