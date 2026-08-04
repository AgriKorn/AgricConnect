import { CreateAddressInput, UpdateAddressInput } from './address.schema';
import { DeliveryAddress } from './address.types';

export interface IAddressRepository {
  findManyByUser(userId: string): Promise<DeliveryAddress[]>;
  findById(id: string): Promise<DeliveryAddress | null>;
  create(userId: string, data: CreateAddressInput): Promise<DeliveryAddress>;
  update(id: string, data: UpdateAddressInput): Promise<DeliveryAddress>;
  delete(id: string): Promise<void>;
  clearDefaultForUser(userId: string): Promise<void>;
}
