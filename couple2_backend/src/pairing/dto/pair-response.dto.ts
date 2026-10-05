export enum PairingStatus {
  PENDING = 'pending',
  PAIRED = 'paired',
}

export class PairResponseDto {
  status: PairingStatus;
  message: string;
  partner?: {
    id: string;
    name: string | null;
  };
}
