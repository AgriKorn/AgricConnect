import { ForbiddenError, NotFoundError } from '../../utils/errors';
import { auditService } from '../audit/audit.service';
import { smsService } from '../../services/sms.service';
import { IUserRepository } from '../user/user.repository';
import { userRepository } from '../user/user.repository.memory';
import { IDispatchRepository } from './dispatch.repository';
import { dispatchRepository } from './dispatch.repository.memory';
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
    private readonly jobs: IDispatchRepository,
    private readonly users: IUserRepository,
  ) {}

  /** Finds the first available driver with sufficient capacity and offers them the job. Returns null if none are free. */
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

    await smsService.sendDriverJobAlert(driver.phone, params.cropType, params.quantityKg);
    await auditService.log('DRIVER_DISPATCHED', params.transactionId, { driverId: driver.id, jobId: job.id }, driver.id);

    return job;
  }

  async acceptJob(jobId: string, driverId: string): Promise<DriverJob> {
    const job = await this.assertOwnedPendingJob(jobId, driverId);
    const updated = await this.jobs.update(job.id, 'ACCEPTED');
    await this.users.updateProfile(driverId, { isAvailable: false });
    await auditService.log('DRIVER_ACCEPTED', job.transactionId, { driverId, jobId: job.id }, driverId);
    return updated;
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

    return { job: declined, reassigned };
  }

  async markCompleted(transactionId: string): Promise<void> {
    const job = await this.jobs.findActiveForTransaction(transactionId);
    if (!job) return;
    await this.jobs.update(job.id, 'COMPLETED');
    await this.users.updateProfile(job.driverId, { isAvailable: true });
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
