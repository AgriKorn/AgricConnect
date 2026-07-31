import { prisma } from '../../config/db';
import { CreateAddressInput, UpdateAddressInput } from './address.schema';
import { IAddressRepository } from './address.repository';
import { DeliveryAddress } from './address.types';

const mapToAddress = (row: any): DeliveryAddress => ({
  id: row.id,
  userId: row.user_id,
  label: row.label,
  addressLine: row.address_line,
  region: row.region,
  isDefault: row.is_default,
  createdAt: row.created_at,
  updatedAt: row.updated_at,
});

export class PrismaAddressRepository implements IAddressRepository {
  async findManyByUser(userId: string): Promise<DeliveryAddress[]> {
    const rows = await prisma.delivery_addresses.findMany({
      where: { user_id: userId },
      orderBy: [{ is_default: 'desc' }, { created_at: 'asc' }],
    });
    return rows.map(mapToAddress);
  }

  async findById(id: string): Promise<DeliveryAddress | null> {
    const row = await prisma.delivery_addresses.findUnique({ where: { id } });
    return row ? mapToAddress(row) : null;
  }

  async create(userId: string, data: CreateAddressInput): Promise<DeliveryAddress> {
    const row = await prisma.delivery_addresses.create({
      data: {
        user_id: userId,
        label: data.label,
        address_line: data.addressLine,
        region: data.region,
        is_default: data.isDefault ?? false,
      },
    });
    return mapToAddress(row);
  }

  async update(id: string, data: UpdateAddressInput): Promise<DeliveryAddress> {
    const row = await prisma.delivery_addresses.update({
      where: { id },
      data: {
        ...(data.label !== undefined && { label: data.label }),
        ...(data.addressLine !== undefined && { address_line: data.addressLine }),
        ...(data.region !== undefined && { region: data.region }),
        ...(data.isDefault !== undefined && { is_default: data.isDefault }),
        updated_at: new Date(),
      },
    });
    return mapToAddress(row);
  }

  async delete(id: string): Promise<void> {
    await prisma.delivery_addresses.delete({ where: { id } });
  }

  async clearDefaultForUser(userId: string): Promise<void> {
    await prisma.delivery_addresses.updateMany({
      where: { user_id: userId, is_default: true },
      data: { is_default: false },
    });
  }
}

export const addressRepository = new PrismaAddressRepository();
