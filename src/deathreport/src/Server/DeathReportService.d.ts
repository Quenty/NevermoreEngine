import { ServiceBag } from '@quenty/servicebag';
import { Signal } from '@quenty/signal';
import { DeathReport, WeaponData } from '../Shared/DeathReportUtils';
import { Observable } from '@quenty/rx';

export interface DeathReportService {
  readonly ServiceName: 'DeathReportService';
  NewDeathReport: Signal<DeathReport>;
  Init(serviceBag: ServiceBag): void;
  AddWeaponDataRetriever(
    getWeaponData: (humanoid: Humanoid) => WeaponData | undefined
  ): () => void;
  FindWeaponData(humanoid: Humanoid): WeaponData | undefined;
  ObservePlayerKillerReports(player: Player): Observable<DeathReport>;
  ObservePlayerDeathReports(player: Player): Observable<DeathReport>;
  ObserveHumanoidKillerReports(humanoid: Humanoid): Observable<DeathReport>;
  ObserveHumanoidDeathReports(humanoid: Humanoid): Observable<DeathReport>;
  ObserveCharacterKillerReports(character: Model): Observable<DeathReport>;
  ObserveCharacterDeathReports(character: Model): Observable<DeathReport>;
  ReportHumanoidDeath(humanoid: Humanoid, weaponData?: WeaponData): void;
  ReportDeathReport(deathReport: DeathReport): void;
  Destroy(): void;
}
