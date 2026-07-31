/**
 * One-off, run-it-yourself script for creating a real admin account —
 * intended for the very first admin (after that, an existing admin can add
 * colleagues via POST /api/admin/admins instead).
 *
 * Deliberately a local script rather than something run through an AI
 * assistant or pasted into a chat: it reads the password from an
 * environment variable on your own machine, so a real credential never has
 * to be typed anywhere except your own terminal.
 *
 * Usage (from backend/, with your local .env pointing at the same
 * Supabase Postgres instance the deployed backend uses):
 *
 *   ADMIN_NAME="Kwame Asante" \
 *   ADMIN_EMAIL="kwame@agriconnect.com" \
 *   ADMIN_PHONE="+233241234567" \
 *   ADMIN_PASSWORD="choose-a-strong-password" \
 *   npx ts-node src/scripts/create-admin.ts
 */
import { createAdminSchema } from '../modules/admin/admin.schema';
import { adminService } from '../modules/admin/admin.service';
import { prisma } from '../config/db';

async function main() {
  const { ADMIN_NAME, ADMIN_EMAIL, ADMIN_PHONE, ADMIN_PASSWORD } = process.env;

  if (!ADMIN_NAME || !ADMIN_EMAIL || !ADMIN_PHONE || !ADMIN_PASSWORD) {
    console.error(
      '❌ Missing one or more required env vars: ADMIN_NAME, ADMIN_EMAIL, ADMIN_PHONE, ADMIN_PASSWORD.\n' +
        '   See the usage comment at the top of this script.',
    );
    process.exit(1);
  }

  const parsed = createAdminSchema.safeParse({
    body: { name: ADMIN_NAME, email: ADMIN_EMAIL, phone: ADMIN_PHONE, password: ADMIN_PASSWORD },
  });

  if (!parsed.success) {
    console.error('❌ Invalid input:', parsed.error.flatten().fieldErrors);
    process.exit(1);
  }

  const admin = await adminService.createAdmin(parsed.data.body);
  console.log(`✅ Admin account created: ${admin.name} <${admin.email}> (${admin.id})`);
  console.log('   They can log in immediately with this email and the password you set.');
}

main()
  .catch((err) => {
    console.error('❌ Failed to create admin:', err.message || err);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
