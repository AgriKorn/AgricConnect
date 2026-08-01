import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { env } from '../../config/env';
import {
  AccountPendingApprovalError,
  AccountRejectedError,
  BadRequestError,
  ConflictError,
  InvalidTokenError,
  NotFoundError,
  OAuthProviderError,
  UnauthorizedError,
} from '../../utils/errors';
import { IUserRepository } from '../user/user.repository';
import { userRepository } from '../user/user.repository.prisma';
import { supabase } from '../../config/supabase';
import { SafeUser, toSafeUser, UserStatus } from '../user/user.types';
import { ForgotPasswordInput, GoogleAuthInput, LoginInput, RegisterInput, ResetPasswordInput } from './auth.schema';
import logger from '../../utils/logger';

const ACCESS_TOKEN_TTL = '15m';
const REFRESH_TOKEN_TTL = '7d';
const RESET_TOKEN_TTL = '15m';

/**
 * The registration form's vehicle-capacity field is free text (hint: "e.g. 2
 * tonnes"), but the column it lands in is kg. Taking the leading number
 * as-is would silently store 2 for a driver who typed "2 tonnes" — 1000x too
 * small — and break dispatch's minimum-capacity matching. Unparseable input
 * falls back to undefined so the caller's existing 1000kg default applies,
 * rather than storing a wrong number with false confidence.
 */
const parseVehicleCapacityKg = (raw?: string): number | undefined => {
  if (!raw) return undefined;
  const match = raw.match(/[\d.]+/);
  if (!match) return undefined;
  const value = parseFloat(match[0]);
  if (!Number.isFinite(value) || value <= 0) return undefined;
  return /tonne|ton\b|tons\b/i.test(raw) ? value * 1000 : value;
};

export class AuthService {
  constructor(private readonly users: IUserRepository) {}

  async register(data: RegisterInput): Promise<{ userId: string; message: string }> {
    const existing = await this.users.findByPhone(data.phone);
    if (existing) throw new ConflictError('Phone number already registered', 'PHONE_ALREADY_REGISTERED');

    const existingEmail = await this.users.findByEmail(data.email);
    if (existingEmail) throw new ConflictError('Email already registered', 'EMAIL_ALREADY_REGISTERED');

    const passwordHash = await bcrypt.hash(data.password, 10);

    const user = await this.users.create({
      name: data.name,
      phone: data.phone,
      email: data.email,
      passwordHash,
      role: data.role,
      otp: '',
      otpExpiry: new Date(),
      region: data.region,
      businessName: data.businessName,
      businessType: data.businessType,
      operatingRegion: data.operatingRegion,
      vehicleCapacityKg: parseVehicleCapacityKg(data.vehicleCapacity),
    });

    const isBuyer = data.role.toLowerCase() === 'buyer';
    const initialStatus: UserStatus = isBuyer ? 'ACTIVE' : 'PENDING_APPROVAL';
    await this.users.update(user.id, { status: initialStatus });

    const message = isBuyer
      ? 'Registration successful. Welcome to AgriConnect!'
      : 'Registration successful. Your account is pending admin approval.';

    return { userId: user.id, message };
  }

  async forgotPassword(data: ForgotPasswordInput): Promise<{ message: string; resetToken?: string }> {
    const user = await this.users.findByEmail(data.email);
    const genericMessage = 'If an account with that email exists, password reset instructions have been generated.';

    if (!user) {
      return { message: genericMessage };
    }

    const resetToken = jwt.sign({ userId: user.id, purpose: 'password_reset' }, env.JWT_SECRET, { expiresIn: RESET_TOKEN_TTL });

    logger.info(`[password-reset] Password reset token generated for ${user.email}: ${resetToken}`);

    return {
      message: genericMessage,
      ...(env.NODE_ENV !== 'production' && { resetToken }),
    };
  }

  async resetPassword(data: ResetPasswordInput): Promise<{ message: string }> {
    let payload: { userId: string; purpose: string };
    try {
      payload = jwt.verify(data.token, env.JWT_SECRET) as { userId: string; purpose: string };
    } catch {
      throw new InvalidTokenError('Password reset token is invalid or has expired');
    }

    if (payload.purpose !== 'password_reset') {
      throw new InvalidTokenError('Invalid token purpose');
    }

    const user = await this.users.findById(payload.userId);
    if (!user) throw new NotFoundError('User not found');

    const newPasswordHash = await bcrypt.hash(data.newPassword, 10);
    await this.users.update(user.id, { passwordHash: newPasswordHash, refreshToken: null });

    return { message: 'Password has been reset successfully. Please log in with your new password.' };
  }

  async login(data: LoginInput): Promise<{ accessToken: string; refreshToken: string; user: SafeUser }> {
    const user = await this.users.findByEmail(data.email);
    if (!user) throw new UnauthorizedError('Invalid credentials');

    const passwordMatches = await bcrypt.compare(data.password, user.passwordHash);
    if (!passwordMatches) throw new UnauthorizedError('Invalid credentials');

    if (user.status === 'REJECTED') throw new AccountRejectedError();
    if (user.status === 'PENDING_APPROVAL') throw new AccountPendingApprovalError();

    const accessToken = jwt.sign({ userId: user.id, role: user.role }, env.JWT_SECRET, { expiresIn: ACCESS_TOKEN_TTL });
    const refreshToken = jwt.sign({ userId: user.id }, env.JWT_REFRESH_SECRET, { expiresIn: REFRESH_TOKEN_TTL });

    const updated = await this.users.update(user.id, { refreshToken });
    return { accessToken, refreshToken, user: toSafeUser(updated) };
  }

  async refresh(refreshToken: string): Promise<{ accessToken: string }> {
    let payload: { userId: string };
    try {
      payload = jwt.verify(refreshToken, env.JWT_REFRESH_SECRET) as { userId: string };
    } catch {
      throw new InvalidTokenError('Refresh token is invalid or expired');
    }

    const user = await this.users.findById(payload.userId);
    if (!user || user.refreshToken !== refreshToken) throw new InvalidTokenError('Refresh token has been revoked or is invalid');

    const accessToken = jwt.sign({ userId: user.id, role: user.role }, env.JWT_SECRET, { expiresIn: ACCESS_TOKEN_TTL });
    return { accessToken };
  }

  async logout(refreshToken: string): Promise<{ message: string }> {
    let payload: { userId: string };
    try {
      payload = jwt.verify(refreshToken, env.JWT_REFRESH_SECRET) as { userId: string };
    } catch {
      return { message: 'Logged out successfully' };
    }

    const user = await this.users.findById(payload.userId);
    if (user && user.refreshToken === refreshToken) {
      await this.users.update(user.id, { refreshToken: null });
    }
    return { message: 'Logged out successfully' };
  }

  async getGoogleAuthUrl(redirectTo?: string): Promise<{ url: string }> {
    try {
      const { data, error } = await supabase.auth.signInWithOAuth({
        provider: 'google',
        options: {
          redirectTo: redirectTo || 'http://localhost:3000/api/auth/google/callback',
          skipBrowserRedirect: true,
        },
      });
      if (error || !data.url) {
        throw new OAuthProviderError(error?.message || 'Failed to generate Google OAuth redirect URL');
      }
      return { url: data.url };
    } catch (err: any) {
      if (err instanceof OAuthProviderError) throw err;
      throw new OAuthProviderError(`Google OAuth service unavailable: ${err.message || 'Unknown network error'}`);
    }
  }

  async googleAuth(data: GoogleAuthInput): Promise<{ accessToken: string; refreshToken: string; user: SafeUser }> {
    let userData;
    try {
      const response = await supabase.auth.getUser(data.token);
      if (response.error || !response.data.user) {
        throw new InvalidTokenError(response.error?.message || 'Invalid or expired Google OAuth token');
      }
      userData = response.data.user;
    } catch (err: any) {
      if (err instanceof InvalidTokenError) throw err;
      throw new OAuthProviderError(`Failed to verify token with Supabase Auth: ${err.message}`);
    }

    const email = userData.email;
    // Google almost never shares a phone number, so a fresh one is minted for
    // brand-new sign-ups only. Returning users MUST be found by email — phone
    // can't be the lookup key here since there is no stable phone to look up.
    const googlePhone = userData.phone || userData.user_metadata?.phone;
    const name = userData.user_metadata?.full_name || userData.user_metadata?.name || email?.split('@')[0] || 'Google User';

    let user = email ? await this.users.findByEmail(email) : null;
    if (!user && googlePhone) {
      user = await this.users.findByPhone(googlePhone);
    }

    if (!user) {
      // Create new user account via OAuth. Same approval rule as phone
      // registration: buyers auto-activate, farmers/drivers need an admin.
      const phone = googlePhone || `+233${Math.floor(100000000 + Math.random() * 900000000)}`;
      const passwordHash = await bcrypt.hash(`oauth_google_${userData.id}`, 10);
      const role = data.role || 'buyer';
      user = await this.users.create({
        name,
        phone,
        email,
        passwordHash,
        role,
        otp: '',
        otpExpiry: new Date(),
      });
      user = await this.users.update(user.id, { status: role === 'buyer' ? 'ACTIVE' : 'PENDING_APPROVAL' });
      logger.info(`[auth-oauth] Created new user ${user.id} via Google OAuth`);
    } else {
      // Account linking / merging: existing user logging in via OAuth
      const updates: Partial<SafeUser> = {};
      if (!user.email && email) updates.email = email;
      if (!user.name || user.name === 'Google User') updates.name = name;
      if (Object.keys(updates).length > 0) {
        user = await this.users.update(user.id, updates);
      }
      logger.info(`[auth-oauth] Linked Google OAuth sign-in for existing user ${user.id}`);
    }

    if (user.status === 'REJECTED') throw new AccountRejectedError();
    if (user.status === 'PENDING_APPROVAL') throw new AccountPendingApprovalError();

    const accessToken = jwt.sign({ userId: user.id, role: user.role }, env.JWT_SECRET, { expiresIn: ACCESS_TOKEN_TTL });
    const refreshToken = jwt.sign({ userId: user.id }, env.JWT_REFRESH_SECRET, { expiresIn: REFRESH_TOKEN_TTL });

    const updated = await this.users.update(user.id, { refreshToken });
    return { accessToken, refreshToken, user: toSafeUser(updated) };
  }
}

export const authService = new AuthService(userRepository);
