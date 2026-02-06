import { BaseObject } from '@quenty/baseobject';
import { Observable } from '@quenty/rx';
import { DeathReport } from './DeathReportUtils';

interface DeathReportProcessor extends BaseObject {
  ObservePlayerKillerReports(player: Player): Observable<DeathReport>;
  ObservePlayerDeathReports(player: Player): Observable<DeathReport>;
  ObserveHumanoidDeathReports(humanoid: Humanoid): Observable<DeathReport>;
  ObserveHumanoidKillerReports(humanoid: Humanoid): Observable<DeathReport>;
  ObserveCharacterKillerReports(character: Model): Observable<DeathReport>;
  ObserveCharacterDeathReports(character: Model): Observable<DeathReport>;
  HandleDeathReport(deathReport: DeathReport): void;
}

interface DeathReportProcessorConstructor {
  readonly ClassName: 'DeathReportProcessor';
  new (): DeathReportProcessor;
}

export const DeathReportProcessor: DeathReportProcessorConstructor;
