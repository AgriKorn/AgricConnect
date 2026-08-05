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
}

export class DispatchService {
  constructor(
    private readonly jobs: PrismaDispatchRepository = dispatchRepository,
    private readonly users: typeof userRepository = userRepository,
  ) {}

  /**
   * Broadcasts the job to every eligible driver at once — each gets their
   * own driver_assignments row, all live simultaneously — rather than
   * offering it to one driver at a time. First to accept gets it (see
   * acceptJob, which expires every sibling offer the instant one is
   * claimed); everyone else just stops seeing it. Returns the first offer
   * created (or null if no driver was eligible at all) — nothing currently
   * depends on which one specifically.
   */
  async assignDriver(params: AssignDriverParams): Promise<DriverJob | null> {
    const candidates = await this.users.findAvailableDrivers(params.quantityKg, []);
    if (candidates.length === 0) return null;

    // create() assigns each row's sequence_number by counting existing rows
    // for the order first — safe run one after another, but a real race if
    // parallelized for the same order (two creates could read the same
    // count before either commits and collide on the unique
    // (order_id, sequence_number) constraint). The audit log + notification
    // for each offer have no such constraint, so those run concurrently
    // afterward instead of sequentially — with a large candidate pool,
    // sequential notification sends alone reproduced live at 90+ seconds
    // for ~22 drivers, which is what made the very first version of this
    // broadcast blow straight past its caller's transaction timeout.
    const jobs: DriverJob[] = [];
    for (const driver of candidates) {
      const job = await this.jobs.create({
        transactionId: params.transactionId,
        listingId: params.listingId,
        driverId: driver.id,
        cropType: params.cropType,
        quantityKg: params.quantityKg,
      });
      jobs.push(job);
    }

    await Promise.all(
      jobs.map((job) =>
        Promise.all([
          auditService.log('DRIVER_DISPATCHED', params.transactionId, { driverId: job.driverId, jobId: job.id }, job.driverId),
          notificationService.sendNotification({
            userId: job.driverId,
            type: 'DRIVER_JOB_OFFERED',
            message: `New delivery job offer: Pickup ${params.quantityKg}kg of ${params.cropType}. Open app to accept or decline.`,
            orderId: params.transactionId,
          }),
        ]),
      ),
    );

    return jobs[0] ?? null;
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

    // A single atomic UPDATE, not read-then-write: the $transaction wrapper
    // this replaced only looked atomic — this.jobs.update()/
    // this.users.updateProfile() go through the raw `prisma` client
    // internally rather than the `tx` handed to the callback, so neither was
    // ever actually rolled back by a later failure (e.g. a slow
    // notification), and neither checked whether a *different*
    // driver_assignments row for the same order had already been accepted.
    // Two live offers for one order (a manual admin assignment overlapping
    // an automatic one, or a race in decline-and-reassign) let two drivers
    // both successfully "accept" the same delivery — reproduced directly
    // against the live DB during this audit. This one statement closes both
    // gaps: it only claims a still-'notified' row, and only when no sibling
    // assignment for the same order is already 'accepted'.
    const claimed = await prisma.$queryRaw<Array<{ id: string }>>`
      UPDATE driver_assignments
      SET status = 'accepted'::assignment_status, responded_at = NOW()
      WHERE id = ${job.id}
        AND status = 'notified'::assignment_status
        AND NOT EXISTS (
          SELECT 1 FROM driver_assignments AS rival
          WHERE rival.order_id = driver_assignments.order_id
            AND rival.status = 'accepted'::assignment_status
        )
      RETURNING id;
    `;

    if (claimed.length === 0) {
      const rival = await prisma.driver_assignments.findFirst({
        where: { order_id: job.transactionId, status: 'accepted' },
      });
      if (rival) throw new ForbiddenError('This order has already been assigned to another driver');
      throw new ForbiddenError(`Job is no longer pending`);
    }

    // The job was broadcast to every eligible driver — now that one has
    // claimed it, every sibling offer has to stop looking live to whoever
    // else it went to, or they'd still see it sitting in their pending list
    // as something they could still accept.
    await prisma.driver_assignments.updateMany({
      where: { order_id: job.transactionId, status: 'notified', id: { not: job.id } },
      data: { status: 'expired', responded_at: new Date() },
    });

    await this.users.updateProfile(driverId, { isAvailable: false });

    await prisma.orders.update({
      where: { id: job.transactionId },
      data: { order_status: 'driver_assigned' },
    });

    await auditService.log('DRIVER_ACCEPTED', job.transactionId, { driverId, jobId: job.id }, driverId);

    const order = await prisma.orders.findUnique({
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

    const updated = await this.jobs.findById(job.id);
    return updated!;
  }

  /**
   * With broadcast dispatch every eligible driver already has their own
   * offer, so declining just removes this driver's copy — no one needs
   * finding a "next" candidate, everyone else already has one. Only once
   * every offer for the order has been declined or timed out with no one
   * accepting does this fall into the same admin-notify exhaustion path
   * both this and the timeout worker (reassignNextDriver) share.
   */
  async declineJob(jobId: string, driverId: string): Promise<{ job: DriverJob; othersStillPending: boolean }> {
    const job = await this.assertOwnedPendingJob(jobId, driverId);
    const declined = await this.jobs.update(job.id, 'DECLINED');

    const othersStillPending = await this.handleExhaustionIfNeeded(job.transactionId, driverId);

    return { job: declined, othersStillPending };
  }

  async markCompleted(transactionId: string): Promise<void> {
    const job = await this.jobs.findActiveForTransaction(transactionId);
    if (!job) return;
    await this.jobs.update(job.id, 'COMPLETED');
    await this.users.updateProfile(job.driverId, { isAvailable: true });
  }

  /**
   * Called by DriverTimeoutWorker once an offer has expired unanswered.
   * Broadcast dispatch means there's no single "next" driver to try — this
   * just checks whether anyone else the job was offered to can still
   * accept, and if the whole pool has declined or expired, runs the
   * exhaustion flow. Multiple siblings for the same order can expire in the
   * same worker batch; the worker dedupes by order_id before calling this
   * so the exhaustion notification only fires once per order, not once per
   * expired row.
   */
  async reassignNextDriver(transactionId: string): Promise<void> {
    await this.handleExhaustionIfNeeded(transactionId, null);
  }

  /** Returns true if at least one other offer for this order can still be accepted. */
  private async handleExhaustionIfNeeded(transactionId: string, actorId: string | null): Promise<boolean> {
    const remaining = await prisma.driver_assignments.count({
      where: { order_id: transactionId, status: { in: ['notified', 'accepted'] } },
    });
    if (remaining > 0) return true;

    // Driver Exhaustion Terminal Case Handling — every driver the job was
    // broadcast to has declined or timed out, and no one accepted.
    const order = await prisma.orders.findUnique({ where: { id: transactionId } });
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

      await auditService.log('DRIVER_DISPATCH_EXHAUSTED' as any, order.id, {}, actorId ?? 'driver-timeout-worker');
    }

    return false;
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
