import logger from '../utils/logger';

/**
 * Stand-in for the real Arkesel-backed SmsService (H5) — no Arkesel account
 * exists yet. Swap the body of send() for a real API call once one does;
 * everything that imports smsService stays the same.
 */
export interface ISmsService {
  sendOtp(phone: string, code: string): Promise<void>;
}

class ConsoleSmsService implements ISmsService {
  async sendOtp(phone: string, code: string): Promise<void> {
    logger.info(`[sms-stub] OTP for ${phone}: ${code}`);
  }
}

export const smsService: ISmsService = new ConsoleSmsService();
