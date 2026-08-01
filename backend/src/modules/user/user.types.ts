export type UserRole = 'farmer' | 'buyer' | 'driver' | 'admin';
export type UserStatus = 'PENDING_OTP' | 'PENDING_APPROVAL' | 'ACTIVE' | 'REJECTED';

export interface FarmerProfile {
  farmRegion?: string;
  gpsLatitude?: number;
  gpsLongitude?: number;
  /** Mobile Money payout number — must be set before a farmer can create listings. */
  momoNumber?: string;
  /** Paystack Ghana mobile-money bank code: 'MTN' | 'VOD' | 'ATL'. */
  momoNetwork?: string;
}

export interface BuyerProfile {
  businessName?: string;
  businessType?: string;
  deliveryAddress?: string;
}

export interface DriverProfile {
  truckCapacity?: number;
  operatingRegion?: string;
  isAvailable?: boolean;
}

export interface User {
  id: string;
  name: string;
  phone: string;
  email: string | null;
  passwordHash: string;
  role: UserRole;
  status: UserStatus;
  otp: string | null;
  otpExpiry: Date | null;
  refreshToken: string | null;
  profile: FarmerProfile & BuyerProfile & DriverProfile;
  createdAt: Date;
  updatedAt: Date;
}

export type SafeUser = Omit<User, 'passwordHash' | 'otp' | 'otpExpiry' | 'refreshToken'>;

export const toSafeUser = (user: User): SafeUser => {
  const { passwordHash: _passwordHash, otp: _otp, otpExpiry: _otpExpiry, refreshToken: _refreshToken, ...safe } = user;
  return safe;
};
