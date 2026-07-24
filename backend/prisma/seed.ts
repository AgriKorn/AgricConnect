import { prisma } from '../src/config/db';
import bcrypt from 'bcryptjs';
import { env } from '../src/config/env';

const DEFAULT_CROPS = [
  { name: 'tomato', category: 'vegetables', basePriceGhsPerKg: 15.5 },
  { name: 'maize', category: 'grains', basePriceGhsPerKg: 8.0 },
  { name: 'cassava', category: 'tubers', basePriceGhsPerKg: 5.2 },
  { name: 'plantain', category: 'fruits', basePriceGhsPerKg: 12.0 },
  { name: 'yam', category: 'tubers', basePriceGhsPerKg: 14.5 },
  { name: 'onion', category: 'vegetables', basePriceGhsPerKg: 18.0 },
  { name: 'pepper', category: 'vegetables', basePriceGhsPerKg: 20.0 },
];

const REGIONS = ['Greater Accra', 'Ashanti', 'Northern', 'Eastern', 'Western', 'Brong-Ahafo'];

export async function main() {
  console.log('🌱 Starting MOFA Market Reference & Crop Types Seeding...');

  // 1. Find or create dummy benchmark system author for audit tracking
  let systemAuthor = await prisma.user.findFirst({ where: { role: 'admin' } });

  // 2. Secure Admin Bootstrapping (Only when explicitly enabled via env vars)
  if (env.BOOTSTRAP_ADMIN_ENABLED === 'true') {
    const adminPhone = env.BOOTSTRAP_ADMIN_PHONE;
    const adminPassword = env.BOOTSTRAP_ADMIN_PASSWORD;

    if (!adminPhone || !adminPassword) {
      throw new Error('❌ BOOTSTRAP_ADMIN_ENABLED is true, but BOOTSTRAP_ADMIN_PHONE or BOOTSTRAP_ADMIN_PASSWORD is not provided.');
    }

    if (adminPassword.length < 12) {
      throw new Error('❌ Bootstrap admin password must be at least 12 characters long.');
    }

    const existingAdmin = await prisma.user.findUnique({ where: { phone_number: adminPhone } });

    if (!existingAdmin) {
      const passwordHash = await bcrypt.hash(adminPassword, 10);
      systemAuthor = await prisma.user.create({
        data: {
          phone_number: adminPhone,
          full_name: 'MOFA Market Administrator',
          role: 'admin',
          region: 'Greater Accra',
          account_status: 'approved',
          otp_verified: true,
          password_hash: passwordHash,
        },
      });
      console.log(`🔒 Secure Administrator account bootstrapped for ${adminPhone}`);
    } else {
      systemAuthor = existingAdmin;
      console.log(`ℹ️ Administrator account already exists for ${adminPhone}. Skipping password reset.`);
    }
  }

  // 3. Seed Crop Types & Regional MOFA Price References (Idempotent)
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  for (const crop of DEFAULT_CROPS) {
    const cropType = await prisma.crop_types.upsert({
      where: { name: crop.name.toLowerCase() },
      update: { category: crop.category.toLowerCase() },
      create: { name: crop.name.toLowerCase(), category: crop.category.toLowerCase() },
    });

    if (systemAuthor) {
      for (const region of REGIONS) {
        await prisma.mofa_price_references.upsert({
          where: {
            crop_type_id_region_effective_date: {
              crop_type_id: cropType.id,
              region,
              effective_date: today,
            },
          },
          update: {
            price_per_kg: crop.basePriceGhsPerKg,
            updated_by: systemAuthor.id,
          },
          create: {
            crop_type_id: cropType.id,
            region,
            price_per_kg: crop.basePriceGhsPerKg,
            effective_date: today,
            updated_by: systemAuthor.id,
          },
        });
      }
    }
  }

  console.log('✅ Crop types and MOFA price references seeded successfully.');
}

if (require.main === module) {
  main()
    .catch((e) => {
      console.error('❌ Seeding failed:', e);
      process.exit(1);
    })
    .finally(async () => {
      await prisma.$disconnect();
    });
}
