import { prisma } from '../../config/db';
import { IMofaPriceRepository } from './pricing.repository';
import { MofaPriceReference } from './pricing.types';

export class PrismaMofaPriceRepository implements IMofaPriceRepository {
  async findLatest(cropType: string, region: string): Promise<MofaPriceReference | null> {
    const found = await prisma.mofa_price_references.findFirst({
      where: {
        crop_types: { name: { equals: cropType, mode: 'insensitive' } },
        region: { equals: region, mode: 'insensitive' },
      },
      include: { crop_types: true },
      orderBy: { effective_date: 'desc' },
    });

    if (found) {
      return {
        cropType: found.crop_types.name,
        region: found.region,
        pricePerKg: Number(found.price_per_kg),
        effectiveDate: found.effective_date,
      };
    }

    // Default fallback baseline if no reference price recorded yet
    return {
      cropType,
      region,
      pricePerKg: 10.0,
      effectiveDate: new Date(),
    };
  }
}

export const mofaPriceRepository = new PrismaMofaPriceRepository();
