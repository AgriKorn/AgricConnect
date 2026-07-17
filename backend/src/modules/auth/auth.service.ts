import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { env } from '../../config/env';
import { BadRequestError, ConflictError, ForbiddenError, NotFoundError, UnauthorizedError } from '../../utils/errors';
import { smsService } from '../../services/sms.service';
import { IUserRepository } from '../user/user.repository';
import { userRepository } from '../user/user.repository.memory';
import { SafeUser, toSafeUser } from '../user/user.types';
import { LoginInput, RegisterInput, VerifyOtpInput } from './auth.schema';

const OTP_TTL_MS = 5 * 60 * 1000;
const ACCESS_TOKEN_TTL = '15m';
const REFRESH_TOKEN_TTL = '7d';

const generateOtp = () => Math.floor(100000 + Math.random() * 900000).toString();

export class AuthService {
  constructor(private readonly users: IUserRepository) {}

  async register(data: RegisterInput): Promise<{ userId: string; message: string }> {
    const existing = await this.users.findByPhone(data.phone);
    if (existing) throw new ConflictError('Phone number already registered');

    const passwordHash = await bcrypt.hash(data.password, 10);
    const otp = generateOtp();
    const otpExpiry = new Date(Date.now() + OTP_TTL_MS);

    const user = await this.users.create({
      name: data.name,
      phone: data.phone,
      passwordHash,
      role: data.role,
      otp,
      otpExpiry,
    });

    await smsService.sendOtp(user.phone, otp);

    return { userId: user.id, message: 'Registration successful. Please verify your OTP.' };
  }

  async verifyOtp(data: VerifyOtpInput): Promise<{ message: string }> {
    const user = await this.users.findByPhone(data.phone);
    if (!user) throw new NotFoundError('User not found');
    if (!user.otp || !user.otpExpiry) throw new BadRequestError('No OTP pending for this account');
    if (user.otpExpiry.getTime() < Date.now()) throw new BadRequestError('OTP has expired. Please request a new one.');
    if (user.otp !== data.otp) throw new BadRequestError('Invalid OTP');

    await this.users.update(user.id, { status: 'PENDING_APPROVAL', otp: null, otpExpiry: null });
    return { message: 'Phone number verified. Your account is pending admin approval.' };
  }

  async login(data: LoginInput): Promise<{ accessToken: string; refreshToken: string; user: SafeUser }> {
    const user = await this.users.findByPhone(data.phone);
    if (!user) throw new UnauthorizedError('Invalid credentials');

    const passwordMatches = await bcrypt.compare(data.password, user.passwordHash);
    if (!passwordMatches) throw new UnauthorizedError('Invalid credentials');

    if (user.status === 'PENDING_OTP') throw new ForbiddenError('Please verify your phone number first');
    if (user.status === 'REJECTED') throw new ForbiddenError('This account has been rejected');

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
      throw new UnauthorizedError('Refresh token is invalid or expired');
    }

    const user = await this.users.findById(payload.userId);
    if (!user || user.refreshToken !== refreshToken) throw new UnauthorizedError('Refresh token has been revoked');

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
}

export const authService = new AuthService(userRepository);
