import { PrismaClient } from '../src/generated/prisma';

const prisma = new PrismaClient();

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

async function main() {
  console.log('🌱 Seeding default crop types, admin system user, and MOFA price references...');

  // 1. Seed System Admin User
  const admin = await prisma.user.upsert({
    where: { phone_number: '+233300000000' },
    update: { account_status: 'approved' },
    create: {
      phone_number: '+233300000000',
      full_name: 'MOFA Market Administrator',
      role: 'admin',
      region: 'Greater Accra',
      account_status: 'approved',
      otp_verified: true,
    },
  });

  console.log(`✅ System Admin verified: ${admin.full_name} (${admin.id})`);

  // 2. Seed Crop Types & MOFA Price References
  const today = new Date();
  today.setHours(0, 0, 0, 0);

  for (const crop of DEFAULT_CROPS) {
    const cropType = await prisma.crop_types.upsert({
      where: { name: crop.name },
      update: { category: crop.category },
      create: { name: crop.name, category: crop.category },
    });

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
          updated_by: admin.id,
        },
        create: {
          crop_type_id: cropType.id,
          region,
          price_per_kg: crop.basePriceGhsPerKg,
          effective_date: today,
          updated_by: admin.id,
        },
      });
    }
  }

  console.log('✅ Default crop types and MOFA regional price references seeded successfully.');
}

main()
  .catch((e) => {
    console.error('❌ Seeding failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
