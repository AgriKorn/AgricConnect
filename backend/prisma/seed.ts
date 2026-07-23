import { PrismaClient } from '../src/generated/prisma';

const prisma = new PrismaClient();

const DEFAULT_CROPS = [
  { name: 'tomato', category: 'vegetables' },
  { name: 'maize', category: 'grains' },
  { name: 'cassava', category: 'tubers' },
  { name: 'plantain', category: 'fruits' },
  { name: 'yam', category: 'tubers' },
  { name: 'onion', category: 'vegetables' },
  { name: 'pepper', category: 'vegetables' },
];

async function main() {
  console.log('🌱 Seeding default crop types and MOFA price references...');

  for (const crop of DEFAULT_CROPS) {
    await prisma.crop_types.upsert({
      where: { name: crop.name },
      update: { category: crop.category },
      create: { name: crop.name, category: crop.category },
    });
  }

  console.log('✅ Default crop types seeded successfully.');
}

main()
  .catch((e) => {
    console.error('❌ Seeding failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
