export interface WeaponData {
  weaponInstance?: Instance;
}
export interface DeathReport {
  type: 'deathReport';
  adornee: Instance;
  humanoid?: Humanoid;
  player?: Player;
  killerAdornee?: Instance;
  killerHumanoid?: Humanoid;
  killerPlayer?: Player;
  weaponData: WeaponData;
}

export namespace DeathReportUtils {
  function create(
    adornee: Instance,
    killerAdornee?: Instance,
    weaponData?: WeaponData
  ): DeathReport;
  function isDeathReport(value: unknown): value is DeathReport;
  function isWeaponData(value: unknown): value is WeaponData;
  function createWeaponData(weaponInstance?: Instance): WeaponData;
  function getDeadDisplayName(deathReport: DeathReport): string | undefined;
  function involvesPlayer(deathReport: DeathReport, player: Player): boolean;
  function getKillerDisplayName(deathReport: DeathReport): string | undefined;
  function getDeadColor(deathReport: DeathReport): Color3 | undefined;
  function getKillerColor(deathReport: DeathReport): Color3 | undefined;
  function getDefaultColor(): Color3;
}
