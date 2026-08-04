import nodemailer, { Transporter } from 'nodemailer';
import logger from '../utils/logger';

export interface EmailService {
  sendPasswordResetEmail(to: string, resetToken: string): Promise<void>;
}

/**
 * Gmail SMTP via nodemailer — a stand-in until a verified sending domain
 * lets us switch to a transactional provider (Resend, picked for later:
 * generous free tier, simplest API). Callers only ever depend on the
 * EmailService interface above, so that swap will only touch this file.
 */
class GmailEmailService implements EmailService {
  private transporter: Transporter | null = null;
  private readonly fromAddress: string;

  constructor() {
    const user = process.env.GMAIL_USER;
    const appPassword = process.env.GMAIL_APP_PASSWORD;
    this.fromAddress = user || '';

    if (user && appPassword) {
      this.transporter = nodemailer.createTransport({
        service: 'gmail',
        auth: { user, pass: appPassword },
      });
    }
  }

  async sendPasswordResetEmail(to: string, resetToken: string): Promise<void> {
    if (!this.transporter) {
      logger.warn('[EmailService] GMAIL_USER/GMAIL_APP_PASSWORD not configured — skipping password reset email.');
      return;
    }

    await this.transporter.sendMail({
      from: `"AgriConnect" <${this.fromAddress}>`,
      to,
      subject: 'Reset your AgriConnect password',
      text: `We received a request to reset your AgriConnect password.\n\nYour reset code:\n${resetToken}\n\nPaste this code into the app's "Reset Code" field. It expires in 15 minutes.\n\nIf you didn't request this, you can safely ignore this email.`,
      html: `<p>We received a request to reset your AgriConnect password.</p>
<p>Your reset code:</p>
<p style="font-family: monospace; font-size: 13px; background: #f0f0f0; padding: 12px; border-radius: 6px; word-break: break-all;">${resetToken}</p>
<p>Paste this code into the app's "Reset Code" field. It expires in 15 minutes.</p>
<p>If you didn't request this, you can safely ignore this email.</p>`,
    });

    logger.info(`[EmailService] Password reset email sent to ${to}`);
  }
}

export const emailService: EmailService = new GmailEmailService();
