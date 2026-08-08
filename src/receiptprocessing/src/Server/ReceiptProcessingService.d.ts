import { Observable } from '@quenty/rx';
import { ServiceBag } from '@quenty/servicebag';

export interface ReceiptProcessingService {
  readonly ServiceName: 'ReceiptProcessingService';
  Init(serviceBag: ServiceBag): void;
  Start(): void;
  SetDefaultPurchaseDecision(
    productPurchaseDecision: Enum.ProductPurchaseDecision
  ): void;
  ObserveReceiptProcessedForPlayer(player: Player): Observable<ReceiptInfo>;
  ObserveReceiptProcessedForUserId(userId: number): Observable<ReceiptInfo>;
  RegisterReceiptProcessor(
    processor: (
      receiptInfo: ReceiptInfo
    ) =>
      | Enum.ProductPurchaseDecision
      | Promise<Enum.ProductPurchaseDecision | undefined>
      | undefined,
    priority?: number
  ): () => void;
  Destroy(): void;
}
