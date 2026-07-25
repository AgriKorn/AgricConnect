import { MofaPriceReference } from './pricing.types';

export interface IMofaPriceRepository {
  findLatest(cropType: string, region: string): Promise<MofaPriceReference | null>;
}
