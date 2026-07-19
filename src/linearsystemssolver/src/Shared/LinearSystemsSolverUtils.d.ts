export namespace LinearSystemsSolverUtils {
  function solve(mutSystem: number[][], mutOutput: number[]): number[];
  function solveTridiagonal(
    mutMainDiag: number[],
    mutUpperDiag: number[],
    mutLowerDiag: number[],
    mutOutput: number[]
  ): number[];
}
