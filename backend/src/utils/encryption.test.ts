/**
 * The module reads FIELD_ENCRYPTION_KEY at call time via loadKey(), so each test
 * sets/clears the env var directly — no module re-import needed.
 */
import crypto from 'crypto';
import { encrypt, decrypt, isEncrypted, encryptNullable, decryptNullable } from './encryption';

const KEY_B64 = crypto.randomBytes(32).toString('base64');
const KEY_HEX = crypto.randomBytes(32).toString('hex');

describe('field encryption (AES-256-GCM)', () => {
  const original = process.env.FIELD_ENCRYPTION_KEY;
  afterEach(() => {
    if (original === undefined) delete process.env.FIELD_ENCRYPTION_KEY;
    else process.env.FIELD_ENCRYPTION_KEY = original;
  });

  describe('with a key configured', () => {
    beforeEach(() => {
      process.env.FIELD_ENCRYPTION_KEY = KEY_B64;
    });

    it('round-trips a value back to the original plaintext', () => {
      const secret = '+233541234567';
      const enc = encrypt(secret);
      expect(enc).not.toBe(secret);
      expect(isEncrypted(enc)).toBe(true);
      expect(decrypt(enc)).toBe(secret);
    });

    it('produces a different ciphertext each time (random IV) for the same input', () => {
      const a = encrypt('same-value');
      const b = encrypt('same-value');
      expect(a).not.toBe(b);
      expect(decrypt(a)).toBe('same-value');
      expect(decrypt(b)).toBe('same-value');
    });

    it('is idempotent: encrypting an already-encrypted value is a no-op', () => {
      const once = encrypt('momo');
      expect(encrypt(once)).toBe(once);
    });

    it('rejects a tampered ciphertext instead of returning garbage', () => {
      const enc = encrypt('+233200000000');
      // Envelope: enc:v1:<iv>:<tag>:<data> — split yields ['enc','v1',iv,tag,data].
      const [e, v, iv, tag, dataB64] = enc.split(':');
      const data = Buffer.from(dataB64, 'base64');
      data[0] = data[0] ^ 0xff;
      const tampered = [e, v, iv, tag, data.toString('base64')].join(':');
      expect(() => decrypt(tampered)).toThrow();
    });

    it('rejects a tampered auth tag', () => {
      const enc = encrypt('+233200000000');
      const [e, v, iv, tagB64, dataB64] = enc.split(':');
      const tag = Buffer.from(tagB64, 'base64');
      tag[0] = tag[0] ^ 0xff;
      const tampered = [e, v, iv, tag.toString('base64'), dataB64].join(':');
      expect(() => decrypt(tampered)).toThrow();
    });

    it('accepts a hex-encoded key as well as base64', () => {
      process.env.FIELD_ENCRYPTION_KEY = KEY_HEX;
      const enc = encrypt('hex-keyed');
      expect(decrypt(enc)).toBe('hex-keyed');
    });

    it('throws on a key of the wrong length', () => {
      process.env.FIELD_ENCRYPTION_KEY = Buffer.from('too-short').toString('base64');
      expect(() => encrypt('x')).toThrow(/32 bytes/);
    });

    it('reads back a legacy plaintext value unchanged (pre-encryption rows)', () => {
      // A value written before encryption existed has no prefix.
      expect(decrypt('+233555000111')).toBe('+233555000111');
    });
  });

  describe('without a key (local dev / tests)', () => {
    beforeEach(() => {
      delete process.env.FIELD_ENCRYPTION_KEY;
    });

    it('passes plaintext through so the app still works', () => {
      expect(encrypt('+233541234567')).toBe('+233541234567');
      expect(decrypt('+233541234567')).toBe('+233541234567');
    });

    it('throws if asked to decrypt a genuinely encrypted value with no key', () => {
      process.env.FIELD_ENCRYPTION_KEY = KEY_B64;
      const enc = encrypt('needs-key');
      delete process.env.FIELD_ENCRYPTION_KEY;
      expect(() => decrypt(enc)).toThrow(/not set/);
    });
  });

  describe('nullable helpers', () => {
    beforeEach(() => {
      process.env.FIELD_ENCRYPTION_KEY = KEY_B64;
    });

    it('passes null and undefined straight through', () => {
      expect(encryptNullable(null)).toBeNull();
      expect(encryptNullable(undefined)).toBeUndefined();
      expect(decryptNullable(null)).toBeNull();
      expect(decryptNullable(undefined)).toBeUndefined();
    });

    it('round-trips a present value', () => {
      const enc = encryptNullable('0244000000');
      expect(enc).not.toBe('0244000000');
      expect(decryptNullable(enc)).toBe('0244000000');
    });
  });
});
