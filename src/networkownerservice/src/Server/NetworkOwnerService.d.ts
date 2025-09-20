export interface NetworkOwnerService {
  Init(): void;
  AddSetNetworkOwnerHandle(
    part: BasePart,
    player: Player | undefined
  ): () => void;
}
