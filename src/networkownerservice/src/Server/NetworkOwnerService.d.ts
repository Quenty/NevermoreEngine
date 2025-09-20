export interface NetworkOwnerService {
  readonly ServiceName: 'NetworkOwnerService';
  Init(): void;
  AddSetNetworkOwnerHandle(
    part: BasePart,
    player: Player | undefined
  ): () => void;
}
