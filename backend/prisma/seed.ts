import { prisma } from '../src/config/db';
import bcrypt from 'bcryptjs';
import { env } from '../src/config/env';

const DEFAULT_CROPS = [
  { name: 'tomato', category: 'vegetables' },
  { name: 'maize', category: 'grains' },
  { name: 'cassava', category: 'tubers' },
  { name: 'plantain', category: 'fruits' },
  { name: 'yam', category: 'tubers' },
  { name: 'onion', category: 'vegetables' },
  { name: 'pepper', category: 'vegetables' },
];

const REGIONS = ['Greater Accra', 'Ashanti', 'Northern', 'Eastern', 'Western', 'Brong-Ahafo'];

/**
 * Regional MOFA reference prices (GHS/kg), replacing the old flat
 * per-crop guess that repeated the same number across every region.
 *
 * Source: WFP "Ghana - Food Prices" dataset on the Humanitarian Data
 * Exchange (https://data.humdata.org/dataset/wfp-food-prices-for-ghana),
 * whose own metadata attributes it to "FPMA, MOFA, Marketing Services
 * Unit, SRID (MOFA) via FAO: GIEWS" — i.e. this is MOFA's own market
 * survey data, republished in structured form. MOFA itself has no public
 * API; its Statistics, Research & Information Directorate only publishes
 * price bulletins as PDFs.
 *
 * IMPORTANT — data recency: this is the most recent structured MOFA price
 * data available from any public source. Checked directly (not assumed):
 * the WFP global price files for 2024, 2025, and 2026 contain zero Ghana
 * rows — the reporting pipeline appears to have stopped after mid-2023
 * and never resumed. effectiveDate below is the actual MOFA survey date
 * for each figure, not a placeholder. Regenerate from a fresher source
 * (e.g. a commercial Esoko API key) if/when one becomes available; until
 * then this is a real historical reference, not an invented number.
 *
 * Methodology: for each crop/region, the wholesale KG price nearest to
 * 2023-07-15 was preferred; where no wholesale KG reading existed for
 * that region, the retail KG price was used instead (all rows below
 * happened to fall back to retail). Where a crop had multiple dataset
 * varieties (e.g. tomato "local"/"navrongo"), fresh-produce varieties
 * were averaged together; dried/processed forms (e.g. dried pepper) were
 * excluded since they are a different product at a different price point.
 *
 * These are the reference prices ListingService.createListing checks a
 * farmer's chosen pricePerKg against (via PricingService) when creating a
 * listing — see backend/src/modules/pricing/pricing.service.ts and
 * backend/src/modules/listing/listing.service.ts.
 */
const MOFA_REGIONAL_PRICES: Record<string, Record<string, { pricePerKg: number; effectiveDate: string }>> = {
  tomato: {
    'Greater Accra': { pricePerKg: 25.98, effectiveDate: '2023-07-15' },
    Ashanti: { pricePerKg: 6.29, effectiveDate: '2023-07-15' },
    Northern: { pricePerKg: 21.43, effectiveDate: '2023-07-15' },
    Eastern: { pricePerKg: 6.65, effectiveDate: '2023-07-15' },
    Western: { pricePerKg: 17.68, effectiveDate: '2023-07-15' },
    'Brong-Ahafo': { pricePerKg: 8.06, effectiveDate: '2023-07-15' },
  },
  maize: {
    'Greater Accra': { pricePerKg: 7.9, effectiveDate: '2023-07-15' },
    Ashanti: { pricePerKg: 9.12, effectiveDate: '2023-07-15' },
    Northern: { pricePerKg: 6.29, effectiveDate: '2023-07-15' },
    Eastern: { pricePerKg: 6.98, effectiveDate: '2023-07-15' },
    Western: { pricePerKg: 12.44, effectiveDate: '2023-07-15' },
    'Brong-Ahafo': { pricePerKg: 4.89, effectiveDate: '2023-07-15' },
  },
  cassava: {
    'Greater Accra': { pricePerKg: 8.75, effectiveDate: '2023-07-15' },
    Ashanti: { pricePerKg: 7.61, effectiveDate: '2023-07-15' },
    Northern: { pricePerKg: 8.97, effectiveDate: '2023-07-15' },
    Eastern: { pricePerKg: 11.22, effectiveDate: '2023-07-15' },
    Western: { pricePerKg: 17.69, effectiveDate: '2023-07-15' },
    'Brong-Ahafo': { pricePerKg: 8.55, effectiveDate: '2023-07-15' },
  },
  plantain: {
    'Greater Accra': { pricePerKg: 9.74, effectiveDate: '2023-07-15' },
    Ashanti: { pricePerKg: 5.36, effectiveDate: '2023-07-15' },
    Northern: { pricePerKg: 7.72, effectiveDate: '2023-07-15' },
    Eastern: { pricePerKg: 7.29, effectiveDate: '2023-07-15' },
    Western: { pricePerKg: 9.31, effectiveDate: '2023-07-15' },
    'Brong-Ahafo': { pricePerKg: 4.8, effectiveDate: '2023-07-15' },
  },
  yam: {
    'Greater Accra': { pricePerKg: 22.0, effectiveDate: '2023-07-15' },
    Ashanti: { pricePerKg: 12.25, effectiveDate: '2023-07-15' },
    Northern: { pricePerKg: 17.8, effectiveDate: '2023-07-15' },
    Eastern: { pricePerKg: 20.0, effectiveDate: '2023-07-15' },
    Western: { pricePerKg: 19.32, effectiveDate: '2023-07-15' },
    'Brong-Ahafo': { pricePerKg: 15.09, effectiveDate: '2023-07-15' },
  },
  onion: {
    'Greater Accra': { pricePerKg: 6.26, effectiveDate: '2023-07-15' },
    Ashanti: { pricePerKg: 3.16, effectiveDate: '2023-07-15' },
    Northern: { pricePerKg: 14.58, effectiveDate: '2023-07-15' },
    // No July reading for this region/crop; nearest available MOFA survey date used instead.
    Eastern: { pricePerKg: 5.25, effectiveDate: '2023-06-15' },
    Western: { pricePerKg: 5.11, effectiveDate: '2023-07-15' },
    'Brong-Ahafo': { pricePerKg: 4.1, effectiveDate: '2023-07-15' },
  },
  pepper: {
    'Greater Accra': { pricePerKg: 9.49, effectiveDate: '2023-07-15' },
    Ashanti: { pricePerKg: 6.3, effectiveDate: '2023-07-15' },
    // No July reading for this region/crop; nearest available MOFA survey date used instead.
    Northern: { pricePerKg: 11.11, effectiveDate: '2023-03-15' },
    Eastern: { pricePerKg: 5.56, effectiveDate: '2023-07-15' },
    Western: { pricePerKg: 3.51, effectiveDate: '2023-07-15' },
    'Brong-Ahafo': { pricePerKg: 3.59, effectiveDate: '2023-07-15' },
  },
};

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
  for (const crop of DEFAULT_CROPS) {
    const cropType = await prisma.crop_types.upsert({
      where: { name: crop.name.toLowerCase() },
      update: { category: crop.category.toLowerCase() },
      create: { name: crop.name.toLowerCase(), category: crop.category.toLowerCase() },
    });

    if (systemAuthor) {
      for (const region of REGIONS) {
        const regional = MOFA_REGIONAL_PRICES[crop.name]?.[region];
        if (!regional) {
          console.warn(`⚠️  No MOFA reference price for ${crop.name} in ${region} — skipping`);
          continue;
        }
        const effectiveDate = new Date(regional.effectiveDate);

        await prisma.mofa_price_references.upsert({
          where: {
            crop_type_id_region_effective_date: {
              crop_type_id: cropType.id,
              region,
              effective_date: effectiveDate,
            },
          },
          update: {
            price_per_kg: regional.pricePerKg,
            updated_by: systemAuthor.id,
          },
          create: {
            crop_type_id: cropType.id,
            region,
            price_per_kg: regional.pricePerKg,
            effective_date: effectiveDate,
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
