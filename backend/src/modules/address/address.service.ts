import { ForbiddenError, NotFoundError } from '../../utils/errors';
import { CreateAddressInput, UpdateAddressInput } from './address.schema';
import { IAddressRepository } from './address.repository';
import { addressRepository } from './address.repository.prisma';
import { DeliveryAddress } from './address.types';

export class AddressService {
  constructor(private readonly repo: IAddressRepository) {}

  async listAddresses(userId: string): Promise<DeliveryAddress[]> {
    return this.repo.findManyByUser(userId);
  }

  async createAddress(userId: string, data: CreateAddressInput): Promise<DeliveryAddress> {
    const existing = await this.repo.findManyByUser(userId);
    // The first address a buyer adds becomes their default automatically —
    // there is no meaningful "not default" state with only one address.
    const isDefault = existing.length === 0 ? true : data.isDefault ?? false;

    if (isDefault && existing.length > 0) {
      await this.repo.clearDefaultForUser(userId);
    }

    return this.repo.create(userId, { ...data, isDefault });
  }

  async updateAddress(userId: string, addressId: string, data: UpdateAddressInput): Promise<DeliveryAddress> {
    await this.assertOwnedAddress(addressId, userId);

    if (data.isDefault === true) {
      await this.repo.clearDefaultForUser(userId);
    }

    return this.repo.update(addressId, data);
  }

  async deleteAddress(userId: string, addressId: string): Promise<void> {
    const address = await this.assertOwnedAddress(addressId, userId);
    await this.repo.delete(addressId);

    if (address.isDefault) {
      const remaining = await this.repo.findManyByUser(userId);
      if (remaining.length > 0) {
        await this.repo.update(remaining[0].id, { isDefault: true });
      }
    }
  }

  private async assertOwnedAddress(addressId: string, userId: string): Promise<DeliveryAddress> {
    const address = await this.repo.findById(addressId);
    if (!address) throw new NotFoundError('Delivery address not found');
    if (address.userId !== userId) throw new ForbiddenError('You can only modify your own delivery addresses');
    return address;
  }
}

export const addressService = new AddressService(addressRepository);
