export class AuthResponseDto {
  accessToken: string;
  user: {
    id: string;
    email: string;
    name: string | null;
    picture: string | null;
    partnerId: string | null;
    pairingCode: string | null;
    pairingCodeExpiresAt: Date | null;
  };
}
