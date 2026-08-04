export interface DeliveryAddress {
  id: string;
  userId: string;
  label: string;
  addressLine: string;
  region: string | null;
  isDefault: boolean;
  createdAt: Date;
  updatedAt: Date;
}

export interface CreateAddressInput {
  label: string;
  addressLine: string;
  region?: string;
  isDefault?: boolean;
}

export interface UpdateAddressInput {
  label?: string;
  addressLine?: string;
  region?: string;
  isDefault?: boolean;
}
