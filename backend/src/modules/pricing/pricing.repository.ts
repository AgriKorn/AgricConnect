import { MofaPriceReference } from './pricing.types';

export interface IMofaPriceRepository {
  findLatest(cropType: string, region: string): Promise<MofaPriceReference | null>;
  /** All recorded reference prices for the given crops/region, newest first — used to compute a real trend. */
  findPriceHistory(cropTypes: string[], region: string): Promise<MofaPriceReference[]>;
}
