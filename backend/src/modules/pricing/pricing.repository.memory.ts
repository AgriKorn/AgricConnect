import { IMofaPriceRepository } from './pricing.repository';
import { MofaPriceReference } from './pricing.types';

/**
 * Temporary in-memory stand-in for the mofa_price_reference table the DB
 * team owns (K4). Seeded with a handful of real crop/region pairs so the
 * pricing endpoint is demoable now — swap for a PrismaMofaPriceRepository
 * once schema.prisma exists.
 */
const SEED: MofaPriceReference[] = [
  { cropType: 'tomato', region: 'greater accra', pricePerKg: 4.0, effectiveDate: new Date('2026-07-14') },
  { cropType: 'tomato', region: 'ashanti', pricePerKg: 3.5, effectiveDate: new Date('2026-07-14') },
  { cropType: 'maize', region: 'ashanti', pricePerKg: 2.2, effectiveDate: new Date('2026-07-14') },
  { cropType: 'cassava', region: 'volta', pricePerKg: 1.8, effectiveDate: new Date('2026-07-14') },
  { cropType: 'plantain', region: 'central', pricePerKg: 2.6, effectiveDate: new Date('2026-07-14') },
];

export class InMemoryMofaPriceRepository implements IMofaPriceRepository {
  private readonly prices = new Map<string, MofaPriceReference>();

  constructor(seed: MofaPriceReference[] = SEED) {
    for (const entry of seed) {
      this.prices.set(this.key(entry.cropType, entry.region), entry);
    }
  }

  async findLatest(cropType: string, region: string): Promise<MofaPriceReference | null> {
    return this.prices.get(this.key(cropType, region)) ?? null;
  }

  private key(cropType: string, region: string): string {
    return `${cropType.toLowerCase()}::${region.toLowerCase()}`;
  }
}

export const mofaPriceRepository = new InMemoryMofaPriceRepository();
