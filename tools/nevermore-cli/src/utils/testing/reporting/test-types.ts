import { type PackageResult, type BatchSummary } from '@quenty/cli-output-helpers/reporting';

/** Test-specific result that extends the generic PackageResult with placeId. */
export interface BatchTestResult extends PackageResult {
  placeId: number;
}

/** Test-specific batch summary. */
export type BatchTestSummary = BatchSummary<BatchTestResult>;
