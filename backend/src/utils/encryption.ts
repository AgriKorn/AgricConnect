import crypto from 'crypto';
import logger from './logger';

/**
 * Authenticated field-level encryption for sensitive data at rest
 * (SRS 3.2 Security: "encrypt all sensitive user information stored in the
 * database"). Used for Mobile Money account numbers — financial PII that must
 * not sit in plaintext in the database.
 *
 * AES-256-GCM: confidential *and* tamper-evident — a modified ciphertext fails
 * the auth tag on decrypt rather than returning garbage. Each value gets a fresh
 * random IV, so identical plaintexts do not produce identical ciphertexts.
 *
 * Stored format: `enc:v1:<iv>:<authTag>:<ciphertext>` (all base64). The version
 * tag lets decrypt tell an encrypted value from a legacy plaintext one, so rows
 * written before this was introduced still read back correctly and can be
 * re-encrypted lazily on their next write.
 *
 * The key comes from FIELD_ENCRYPTION_KEY (32 bytes, base64 or hex). When it is
 * absent — local dev and the test runner — encryption is a pass-through so the
 * app still works without a key; a single warning is logged. Production must set
 * the key (documented in .env.example / README).
 */

const PREFIX = 'enc:v1:';
const ALGORITHM = 'aes-256-gcm';
const IV_BYTES = 12; // GCM standard nonce length

let warned = false;

const loadKey = (): Buffer | null => {
  const raw = process.env.FIELD_ENCRYPTION_KEY;
  if (!raw) {
    if (!warned) {
      logger.warn(
        '[encryption] FIELD_ENCRYPTION_KEY is not set — sensitive fields are stored in plaintext. Set a 32-byte key (base64 or hex) in production.',
      );
      warned = true;
    }
    return null;
  }
  // Accept base64 or hex; both must decode to exactly 32 bytes for AES-256.
  const key = /^[0-9a-fA-F]{64}$/.test(raw) ? Buffer.from(raw, 'hex') : Buffer.from(raw, 'base64');
  if (key.length !== 32) {
    throw new Error(
      `[encryption] FIELD_ENCRYPTION_KEY must decode to 32 bytes for AES-256; got ${key.length}. Provide 32 bytes as hex (64 chars) or base64.`,
    );
  }
  return key;
};

/** True if a value is already in our encrypted envelope. */
export const isEncrypted = (value: string): boolean => value.startsWith(PREFIX);

/**
 * Encrypts a plaintext string. Returns the `enc:v1:...` envelope, or the
 * original value unchanged when no key is configured (dev/test) or the value is
 * already encrypted (idempotent).
 */
export const encrypt = (plaintext: string): string => {
  if (isEncrypted(plaintext)) return plaintext;
  const key = loadKey();
  if (!key) return plaintext;

  const iv = crypto.randomBytes(IV_BYTES);
  const cipher = crypto.createCipheriv(ALGORITHM, key, iv);
  const ciphertext = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
  const authTag = cipher.getAuthTag();

  return `${PREFIX}${iv.toString('base64')}:${authTag.toString('base64')}:${ciphertext.toString('base64')}`;
};

/**
 * Decrypts an `enc:v1:...` value. A value without the prefix is returned as-is
 * (legacy plaintext, or dev without a key), so reads never break on old rows.
 * Throws only when the envelope is malformed or fails authentication — a signal
 * of tampering or a wrong key, which must not pass silently.
 */
export const decrypt = (value: string): string => {
  if (!isEncrypted(value)) return value;

  const key = loadKey();
  if (!key) {
    throw new Error('[encryption] Found an encrypted value but FIELD_ENCRYPTION_KEY is not set — cannot decrypt.');
  }

  const parts = value.slice(PREFIX.length).split(':');
  if (parts.length !== 3) {
    throw new Error('[encryption] Malformed encrypted value: expected iv:authTag:ciphertext.');
  }
  const [ivB64, tagB64, dataB64] = parts;
  const decipher = crypto.createDecipheriv(ALGORITHM, key, Buffer.from(ivB64, 'base64'));
  decipher.setAuthTag(Buffer.from(tagB64, 'base64'));
  const plaintext = Buffer.concat([decipher.update(Buffer.from(dataB64, 'base64')), decipher.final()]);
  return plaintext.toString('utf8');
};

/** Convenience for optional/nullable fields: passes null/undefined straight through. */
export const encryptNullable = (value: string | null | undefined): string | null | undefined =>
  value == null ? value : encrypt(value);

export const decryptNullable = (value: string | null | undefined): string | null | undefined =>
  value == null ? value : decrypt(value);
