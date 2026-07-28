import bcrypt from 'bcryptjs';
import logger from '../../utils/logger';
import { userRepository } from './user.repository.prisma';

const DEV_ADMIN_PHONE = '+233200000000';
const DEV_ADMIN_PASSWORD = 'admin12345';

/**
 * Dev/demo convenience only: admin accounts can't self-register (by design —
 * registerSchema's role enum excludes 'admin'), and there's no real database
 * yet to seed from. Ensures one ACTIVE admin exists so the approval flow is
 * demoable without manual setup. Never runs in production.
 */
export const seedDevAdmin = async (): Promise<void> => {
  const existing = await userRepository.findByPhone(DEV_ADMIN_PHONE);
  if (existing) return;

  const passwordHash = await bcrypt.hash(DEV_ADMIN_PASSWORD, 10);
  const admin = await userRepository.create({
    name: 'Dev Admin',
    phone: DEV_ADMIN_PHONE,
    passwordHash,
    role: 'admin',
    otp: '',
    otpExpiry: new Date(),
  });
  await userRepository.update(admin.id, { status: 'ACTIVE', otp: null, otpExpiry: null });

  logger.info(`[dev-seed] Admin ready — phone: ${DEV_ADMIN_PHONE}, password: ${DEV_ADMIN_PASSWORD}`);
};
