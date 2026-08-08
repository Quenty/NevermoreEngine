import { Observable } from '@quenty/rx';
import { ServiceBag } from '@quenty/servicebag';
import { DeathReport } from '../Shared/DeathReportUtils';

export interface DeathReportServiceClient {
  readonly ServiceName: 'DeathReportServiceClient';
  Init(serviceBag: ServiceBag): void;
  ObservePlayerKillerReports(player: Player): Observable<DeathReport>;
  ObservePlayerDeathReports(player: Player): Observable<DeathReport>;
  ObserveHumanoidKillerReports(humanoid: Humanoid): Observable<DeathReport>;
  ObserveHumanoidDeathReports(humanoid: Humanoid): Observable<DeathReport>;
  ObserveCharacterKillerReports(character: Model): Observable<DeathReport>;
  ObserveCharacterDeathReports(character: Model): Observable<DeathReport>;
  GetLastDeathReports(): DeathReport[];
  Destroy(): void;
}
