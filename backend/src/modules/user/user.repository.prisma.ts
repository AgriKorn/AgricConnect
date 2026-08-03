import { prisma } from '../../config/db';
import { CreateUserRecord, IUserRepository } from './user.repository';
import { User, UserRole, UserStatus } from './user.types';
import { account_status, user_role, driver_availability } from '../../generated/prisma/client';

const statusToPrisma = (status: UserStatus): account_status => {
  switch (status) {
    case 'ACTIVE':
      return 'approved';
    case 'REJECTED':
      return 'rejected';
    case 'PENDING_APPROVAL':
    case 'PENDING_OTP':
    default:
      return 'pending';
  }
};

const statusFromPrisma = (status: account_status): UserStatus => {
  switch (status) {
    case 'approved':
      return 'ACTIVE';
    case 'rejected':
      return 'REJECTED';
    case 'pending':
    default:
      return 'PENDING_APPROVAL';
  }
};

const mapPrismaToUser = (p: any): User => {
  const driver = p.driver_details;
  return {
    id: p.id,
    name: p.full_name,
    phone: p.phone_number,
    email: p.email || null,
    passwordHash: p.password_hash || '',
    role: p.role as UserRole,
    status: statusFromPrisma(p.account_status),
    otp: null,
    otpExpiry: null,
    refreshToken: p.refresh_token || null,
    profile: {
      farmRegion: p.region || undefined,
      operatingRegion: driver?.operating_region || p.region || undefined,
      truckCapacity: driver ? Number(driver.truck_capacity_kg) : undefined,
      isAvailable: driver ? driver.availability_status === 'available' : undefined,
      momoNumber: p.momo_number || undefined,
      momoNetwork: p.momo_network || undefined,
      businessName: p.business_name || undefined,
      businessType: p.business_type || undefined,
      photoUrl: p.photo_url || undefined,
      notificationPreferences: p.notification_prefs || undefined,
    },
    createdAt: p.created_at,
    updatedAt: p.updated_at,
  };
};

export class PrismaUserRepository implements IUserRepository {
  async create(data: CreateUserRecord): Promise<User> {
    const created = await prisma.user.create({
      data: {
        phone_number: data.phone,
        full_name: data.name,
        password_hash: data.passwordHash,
        role: data.role as user_role,
        region: data.region || 'Greater Accra',
        account_status: data.role === 'buyer' ? 'approved' : 'pending',
        ...(data.email && { email: data.email }),
        ...(data.businessName && { business_name: data.businessName }),
        ...(data.businessType && { business_type: data.businessType }),
      },
    });

    if (data.role === 'driver') {
      await prisma.driver_details.create({
        data: {
          user_id: created.id,
          truck_capacity_kg: data.vehicleCapacityKg || 1000,
          operating_region: data.operatingRegion || data.region || 'Greater Accra',
          availability_status: 'available',
        },
      });
    }

    const full = await this.findById(created.id);
    return full!;
  }

  async findByPhone(phone: string): Promise<User | null> {
    const found = await prisma.user.findUnique({
      where: { phone_number: phone },
      include: { driver_details: true },
    });
    return found ? mapPrismaToUser(found) : null;
  }

  async findByEmail(email: string): Promise<User | null> {
    const found = await prisma.user.findUnique({
      where: { email },
      include: { driver_details: true },
    });
    return found ? mapPrismaToUser(found) : null;
  }

  async findById(id: string): Promise<User | null> {
    const found = await prisma.user.findUnique({
      where: { id },
      include: { driver_details: true },
    });
    return found ? mapPrismaToUser(found) : null;
  }

  async findManyByStatus(status: UserStatus): Promise<User[]> {
    const list = await prisma.user.findMany({
      where: { account_status: statusToPrisma(status) },
      include: { driver_details: true },
      // Newest first — an admin reviewing a growing queue should see what
      // just came in without scrolling past everything already waiting.
      orderBy: { created_at: 'desc' },
    });
    return list.map(mapPrismaToUser);
  }

  async findManyByRole(role: UserRole): Promise<User[]> {
    const list = await prisma.user.findMany({
      where: { role: role as user_role },
      include: { driver_details: true },
      orderBy: { created_at: 'desc' },
    });
    return list.map(mapPrismaToUser);
  }

  async findFarmerIdsByRegion(region: string): Promise<string[]> {
    const list = await prisma.user.findMany({
      where: { role: 'farmer', region: { equals: region, mode: 'insensitive' } },
      select: { id: true },
    });
    return list.map((u) => u.id);
  }

  async findAvailableDrivers(minCapacityKg: number, excludeIds: string[]): Promise<User[]> {
    const list = await prisma.user.findMany({
      where: {
        role: 'driver',
        account_status: 'approved',
        id: excludeIds.length > 0 ? { notIn: excludeIds } : undefined,
        driver_details: {
          availability_status: 'available',
          truck_capacity_kg: { gte: minCapacityKg },
        },
      },
      include: { driver_details: true },
    });
    return list.map(mapPrismaToUser);
  }

  async update(id: string, data: Partial<User>): Promise<User> {
    const updateData: any = {};
    if (data.name) updateData.full_name = data.name;
    if (data.email !== undefined) updateData.email = data.email;
    if (data.status) updateData.account_status = statusToPrisma(data.status);
    if (data.refreshToken !== undefined) updateData.refresh_token = data.refreshToken;
    // AuthService.resetPassword writes the new hash through this method; without
    // this line the reset reports success and silently changes nothing.
    if (data.passwordHash !== undefined) updateData.password_hash = data.passwordHash;

    await prisma.user.update({
      where: { id },
      data: updateData,
    });

    const updated = await this.findById(id);
    return updated!;
  }

  async updateProfile(id: string, profile: Partial<User['profile']>): Promise<User> {
    if (
      profile.farmRegion ||
      profile.operatingRegion ||
      profile.momoNumber ||
      profile.momoNetwork ||
      profile.businessName ||
      profile.businessType ||
      profile.photoUrl ||
      profile.notificationPreferences
    ) {
      await prisma.user.update({
        where: { id },
        data: {
          ...((profile.farmRegion || profile.operatingRegion) && { region: profile.farmRegion || profile.operatingRegion }),
          ...(profile.momoNumber && { momo_number: profile.momoNumber }),
          ...(profile.momoNetwork && { momo_network: profile.momoNetwork }),
          ...(profile.businessName && { business_name: profile.businessName }),
          ...(profile.businessType && { business_type: profile.businessType }),
          ...(profile.photoUrl && { photo_url: profile.photoUrl }),
          ...(profile.notificationPreferences && { notification_prefs: profile.notificationPreferences }),
        },
      });
    }

    if (profile.truckCapacity !== undefined || profile.isAvailable !== undefined) {
      const avail: driver_availability = profile.isAvailable ? 'available' : 'offline';
      await prisma.driver_details.upsert({
        where: { user_id: id },
        update: {
          ...(profile.truckCapacity !== undefined && { truck_capacity_kg: profile.truckCapacity }),
          ...(profile.isAvailable !== undefined && { availability_status: avail }),
          ...(profile.operatingRegion && { operating_region: profile.operatingRegion }),
        },
        create: {
          user_id: id,
          truck_capacity_kg: profile.truckCapacity ?? 1000,
          operating_region: profile.operatingRegion || 'Greater Accra',
          availability_status: avail,
        },
      });
    }

    const updated = await this.findById(id);
    return updated!;
  }

  async updateFcmToken(id: string, fcmToken: string): Promise<User> {
    await prisma.user.update({
      where: { id },
      data: { fcm_token: fcmToken },
    });
    await this.registerDeviceToken(id, fcmToken);
    const updated = await this.findById(id);
    return updated!;
  }

  async registerDeviceToken(userId: string, token: string, platform?: string, deviceId?: string): Promise<void> {
    await prisma.user_device_tokens.upsert({
      where: { token },
      update: {
        user_id: userId,
        platform: platform || undefined,
        device_id: deviceId || undefined,
        is_active: true,
        last_used_at: new Date(),
        updated_at: new Date(),
      },
      create: {
        user_id: userId,
        token,
        platform: platform || null,
        device_id: deviceId || null,
        is_active: true,
      },
    });
  }

  async removeDeviceToken(userId: string, token: string): Promise<void> {
    await prisma.user_device_tokens.updateMany({
      where: { user_id: userId, token },
      data: { is_active: false, updated_at: new Date() },
    });
  }

  async findActiveDeviceTokens(userId: string): Promise<string[]> {
    const tokens: string[] = [];

    try {
      const list = await prisma.user_device_tokens.findMany({
        where: { user_id: userId, is_active: true },
        select: { token: true },
      });
      if (list) {
        tokens.push(...list.map((t) => t.token));
      }
    } catch (_err) {
      // Table may not exist yet or mock in unit test
    }

    try {
      // Also fallback check single legacy User.fcm_token column
      const user = await prisma.user.findUnique({
        where: { id: userId },
        select: { fcm_token: true },
      });
      if (user?.fcm_token && !tokens.includes(user.fcm_token)) {
        tokens.push(user.fcm_token);
      }
    } catch (_err) {
      // Ignore
    }

    return Array.from(new Set(tokens));
  }

  async deactivateDeviceToken(token: string): Promise<void> {
    await prisma.user_device_tokens.updateMany({
      where: { token },
      data: { is_active: false, updated_at: new Date() },
    });
  }
}

export const userRepository = new PrismaUserRepository();
