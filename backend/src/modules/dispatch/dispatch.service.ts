import { prisma } from '../../config/db';
import { BadRequestError, ForbiddenError, NotFoundError } from '../../utils/errors';
import { auditService } from '../audit/audit.service';
import { notificationService } from '../notification/notification.service';
import { userRepository } from '../user/user.repository.prisma';
import { dispatchRepository, PrismaDispatchRepository } from './dispatch.repository.prisma';
import { DriverJob } from './dispatch.types';

export interface AssignDriverParams {
  transactionId: string;
  listingId: string;
  cropType: string;
  quantityKg: number;
  excludeDriverIds?: string[];
}

export class DispatchService {
  constructor(
    private readonly jobs: PrismaDispatchRepository = dispatchRepository,
    private readonly users: typeof userRepository = userRepository,
  ) {}

  async assignDriver(params: AssignDriverParams): Promise<DriverJob | null> {
    const candidates = await this.users.findAvailableDrivers(params.quantityKg, params.excludeDriverIds ?? []);
    const driver = candidates[0];
    if (!driver) return null;

    const job = await this.jobs.create({
      transactionId: params.transactionId,
      listingId: params.listingId,
      driverId: driver.id,
      cropType: params.cropType,
      quantityKg: params.quantityKg,
    });

    await auditService.log('DRIVER_DISPATCHED', params.transactionId, { driverId: driver.id, jobId: job.id }, driver.id);

    await notificationService.sendNotification({
      userId: driver.id,
      type: 'DRIVER_JOB_OFFERED',
      message: `New delivery job offer: Pickup ${params.quantityKg}kg of ${params.cropType}. Open app to accept or decline.`,
      orderId: params.transactionId,
    });

    return job;
  }

  getDriverJobs(driverId: string, status?: DriverJob['status']): Promise<DriverJob[]> {
    return this.jobs.findJobsForDriver(driverId, status);
  }

  /**
   * Admin override for the driver-exhaustion terminal case in declineJob —
   * picks a specific driver rather than the automatic capacity-based match,
   * since exhaustion means no candidate was available/willing.
   */
  async manualAssignDriver(transactionId: string, driverId: string, assignedBy: string): Promise<DriverJob> {
    const order = await prisma.orders.findUnique({
      where: { id: transactionId },
      include: { produce_listings: { include: { crop_types: true } } },
    });
    if (!order) throw new NotFoundError('Order not found');

    const driver = await this.users.findById(driverId);
    if (!driver || driver.role !== 'driver') throw new BadRequestError('Driver not found or not a driver account');

    const cropType = order.produce_listings?.crop_types?.name || 'crop';
    const quantityKg = order.produce_listings ? Number(order.produce_listings.quantity_kg) : 0;

    const job = await this.jobs.create({
      transactionId: order.id,
      listingId: order.listing_id,
      driverId: driver.id,
      cropType,
      quantityKg,
    });

    await auditService.log('DRIVER_MANUALLY_ASSIGNED' as any, transactionId, { driverId, jobId: job.id }, assignedBy);

    await notificationService.sendNotification({
      userId: driver.id,
      type: 'DRIVER_JOB_OFFERED',
      message: `New delivery job offer: Pickup ${quantityKg}kg of ${cropType}. Open app to accept or decline.`,
      orderId: transactionId,
    });

    return job;
  }

  async findActiveForTransaction(transactionId: string): Promise<DriverJob | null> {
    return this.jobs.findActiveForTransaction(transactionId);
  }

  async acceptJob(jobId: string, driverId: string): Promise<DriverJob> {
    const job = await this.assertOwnedPendingJob(jobId, driverId);

    return await prisma.$transaction(async (tx) => {
      const updated = await this.jobs.update(job.id, 'ACCEPTED');
      await this.users.updateProfile(driverId, { isAvailable: false });

      await tx.orders.update({
        where: { id: job.transactionId },
        data: { order_status: 'driver_assigned' },
      });

      await auditService.log('DRIVER_ACCEPTED', job.transactionId, { driverId, jobId: job.id }, driverId);

      const order = await tx.orders.findUnique({
        where: { id: job.transactionId },
        include: { produce_listings: true },
      });

      if (order) {
        await notificationService.sendNotification({
          userId: order.buyer_id,
          type: 'DRIVER_ACCEPTED_BUYER',
          message: `A driver has accepted the transport assignment for Order #${order.id}.`,
          orderId: order.id,
        });

        await notificationService.sendNotification({
          userId: order.produce_listings.farmer_id,
          type: 'DRIVER_ACCEPTED_FARMER',
          message: `A driver has accepted transport for Order #${order.id}. Produce pickup is scheduled.`,
          orderId: order.id,
        });
      }

      return updated;
    });
  }

  async declineJob(jobId: string, driverId: string): Promise<{ job: DriverJob; reassigned: DriverJob | null }> {
    const job = await this.assertOwnedPendingJob(jobId, driverId);
    const declined = await this.jobs.update(job.id, 'DECLINED');

    const priorAttempts = await this.jobs.findAllForTransaction(job.transactionId);
    const excludeDriverIds = priorAttempts.map((attempt) => attempt.driverId);

    const reassigned = await this.assignDriver({
      transactionId: job.transactionId,
      listingId: job.listingId,
      cropType: job.cropType,
      quantityKg: job.quantityKg,
      excludeDriverIds,
    });

    if (!reassigned) {
      // Driver Exhaustion Terminal Case Handling
      const order = await prisma.orders.findUnique({ where: { id: job.transactionId } });
      if (order) {
        await prisma.orders.update({
          where: { id: order.id },
          data: { order_status: 'awaiting_driver' },
        });

        const admins = await prisma.user.findMany({ where: { role: 'admin' } });
        for (const admin of admins) {
          await notificationService.sendNotification({
            userId: admin.id,
            type: 'MANUAL_DISPATCH_REQUIRED',
            message: `Order #${order.id} has no remaining available drivers in the operating region. Manual driver assignment required via POST /api/admin/dispatch/assign.`,
            orderId: order.id,
          });
        }

        await notificationService.sendNotification({
          userId: order.buyer_id,
          type: 'DISPATCH_DELAYED',
          message: `Your order #${order.id} is confirmed! We are matching specialized transport for your crop and will notify you as soon as a driver is assigned.`,
          orderId: order.id,
        });

        await auditService.log('DRIVER_DISPATCH_EXHAUSTED' as any, order.id, { declinedDrivers: excludeDriverIds }, driverId);
      }
    }

    return { job: declined, reassigned };
  }

  async markCompleted(transactionId: string): Promise<void> {
    const job = await this.jobs.findActiveForTransaction(transactionId);
    if (!job) return;
    await this.jobs.update(job.id, 'COMPLETED');
    await this.users.updateProfile(job.driverId, { isAvailable: true });
  }

  async reassignNextDriver(transactionId: string): Promise<DriverJob | null> {
    const priorAttempts = await this.jobs.findAllForTransaction(transactionId);
    if (priorAttempts.length === 0) return null;
    const latestAttempt = priorAttempts[priorAttempts.length - 1];
    const excludeDriverIds = priorAttempts.map((attempt) => attempt.driverId);

    return await this.assignDriver({
      transactionId,
      listingId: latestAttempt.listingId,
      cropType: latestAttempt.cropType,
      quantityKg: latestAttempt.quantityKg,
      excludeDriverIds,
    });
  }

  private async assertOwnedPendingJob(jobId: string, driverId: string): Promise<DriverJob> {
    const job = await this.jobs.findById(jobId);
    if (!job) throw new NotFoundError('Driver job not found');
    if (job.driverId !== driverId) throw new ForbiddenError('This job was not offered to you');
    if (job.status !== 'PENDING') throw new ForbiddenError(`Job is no longer pending (status: ${job.status})`);
    return job;
  }
}

export const dispatchService = new DispatchService(dispatchRepository, userRepository);
