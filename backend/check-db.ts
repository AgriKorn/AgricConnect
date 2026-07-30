import { prisma } from './src/config/db';

async function verifySupabase() {
  const users = await prisma.user.count();
  const crops = await prisma.crop_types.count();
  const prices = await prisma.mofa_price_references.count();
  const listings = await prisma.produce_listings.count();

  console.log('====================================================');
  console.log('✅ SUPABASE POSTGRESQL DATABASE IS 100% CONNECTED & LIVE!');
  console.log('====================================================');
  console.log(`- Supabase Host: elqvrqydxpykxurmziky.supabase.co`);
  console.log(`- Registered Users: ${users}`);
  console.log(`- Seeded Crop Types: ${crops}`);
  console.log(`- Seeded MOFA Price References: ${prices}`);
  console.log(`- Produce Listings in DB: ${listings}`);
  console.log('====================================================');

  await prisma.$disconnect();
}

verifySupabase().catch(console.error);
