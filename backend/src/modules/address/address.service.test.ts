import { AddressService } from './address.service';
import { IAddressRepository } from './address.repository';
import { DeliveryAddress } from './address.types';
import { ForbiddenError, NotFoundError } from '../../utils/errors';

describe('AddressService', () => {
  let mockRepo: jest.Mocked<IAddressRepository>;
  let addressService: AddressService;

  const createAddress = (overrides?: Partial<DeliveryAddress>): DeliveryAddress => ({
    id: 'addr-1',
    userId: 'user-1',
    label: 'Home',
    addressLine: 'House No. 24, Spintex Road, Accra',
    region: 'Greater Accra',
    isDefault: false,
    createdAt: new Date('2026-07-01'),
    updatedAt: new Date('2026-07-01'),
    ...overrides,
  });

  beforeEach(() => {
    jest.clearAllMocks();
    mockRepo = {
      findManyByUser: jest.fn(),
      findById: jest.fn(),
      create: jest.fn(),
      update: jest.fn(),
      delete: jest.fn(),
      clearDefaultForUser: jest.fn(),
    };
    addressService = new AddressService(mockRepo);
  });

  describe('listAddresses', () => {
    it('should return the addresses belonging to the given user', async () => {
      mockRepo.findManyByUser.mockResolvedValue([createAddress()]);

      const result = await addressService.listAddresses('user-1');

      expect(mockRepo.findManyByUser).toHaveBeenCalledWith('user-1');
      expect(result).toHaveLength(1);
    });
  });

  describe('createAddress', () => {
    it('should make the first address a user adds the default automatically', async () => {
      mockRepo.findManyByUser.mockResolvedValue([]);
      mockRepo.create.mockResolvedValue(createAddress({ isDefault: true }));

      await addressService.createAddress('user-1', { label: 'Home', addressLine: '123 Main St' });

      expect(mockRepo.create).toHaveBeenCalledWith('user-1', expect.objectContaining({ isDefault: true }));
      expect(mockRepo.clearDefaultForUser).not.toHaveBeenCalled();
    });

    it('should not default a second address unless explicitly requested', async () => {
      mockRepo.findManyByUser.mockResolvedValue([createAddress()]);
      mockRepo.create.mockResolvedValue(createAddress({ id: 'addr-2', isDefault: false }));

      await addressService.createAddress('user-1', { label: 'Office', addressLine: '456 Ridge Rd' });

      expect(mockRepo.create).toHaveBeenCalledWith('user-1', expect.objectContaining({ isDefault: false }));
    });

    it('should clear the previous default when a new address is explicitly marked default', async () => {
      mockRepo.findManyByUser.mockResolvedValue([createAddress()]);
      mockRepo.create.mockResolvedValue(createAddress({ id: 'addr-2', isDefault: true }));

      await addressService.createAddress('user-1', { label: 'Office', addressLine: '456 Ridge Rd', isDefault: true });

      expect(mockRepo.clearDefaultForUser).toHaveBeenCalledWith('user-1');
    });
  });

  describe('updateAddress', () => {
    it('should throw NotFoundError when the address does not exist', async () => {
      mockRepo.findById.mockResolvedValue(null);

      await expect(addressService.updateAddress('user-1', 'missing', { label: 'New' })).rejects.toThrow(NotFoundError);
    });

    it("should throw ForbiddenError when the address belongs to someone else", async () => {
      mockRepo.findById.mockResolvedValue(createAddress({ userId: 'someone-else' }));

      await expect(addressService.updateAddress('user-1', 'addr-1', { label: 'New' })).rejects.toThrow(ForbiddenError);
    });

    it('should clear other defaults when this address is set as default', async () => {
      mockRepo.findById.mockResolvedValue(createAddress());
      mockRepo.update.mockResolvedValue(createAddress({ isDefault: true }));

      await addressService.updateAddress('user-1', 'addr-1', { isDefault: true });

      expect(mockRepo.clearDefaultForUser).toHaveBeenCalledWith('user-1');
    });
  });

  describe('deleteAddress', () => {
    it('should reject deleting an address that is not the caller\'s', async () => {
      mockRepo.findById.mockResolvedValue(createAddress({ userId: 'someone-else' }));

      await expect(addressService.deleteAddress('user-1', 'addr-1')).rejects.toThrow(ForbiddenError);
      expect(mockRepo.delete).not.toHaveBeenCalled();
    });

    it('should promote a remaining address to default when the default one is deleted', async () => {
      mockRepo.findById.mockResolvedValue(createAddress({ isDefault: true }));
      mockRepo.findManyByUser.mockResolvedValue([createAddress({ id: 'addr-2', isDefault: false })]);

      await addressService.deleteAddress('user-1', 'addr-1');

      expect(mockRepo.delete).toHaveBeenCalledWith('addr-1');
      expect(mockRepo.update).toHaveBeenCalledWith('addr-2', { isDefault: true });
    });

    it('should not touch other addresses when a non-default address is deleted', async () => {
      mockRepo.findById.mockResolvedValue(createAddress({ isDefault: false }));

      await addressService.deleteAddress('user-1', 'addr-1');

      expect(mockRepo.delete).toHaveBeenCalledWith('addr-1');
      expect(mockRepo.update).not.toHaveBeenCalled();
    });
  });
});
