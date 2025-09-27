export namespace ColorGradeUtils {
  function addGrade(grade: number, difference: number): number;
  function addGradeToColor(color: Color3, difference: number): Color3;
  function ensureGradeContrast(
    color: Color3,
    backing: Color3,
    amount: number
  ): Color3;
  function getGrade(color: Color3): number;
  function getGradedColor(
    baseColor: Color3,
    colorGrade: number,
    vididness?: number
  ): Color3;
}
