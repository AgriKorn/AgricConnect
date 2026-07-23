import { randomUUID } from 'crypto';
import { NotFoundError } from '../../utils/errors';
import { DriverJob, DriverJobStatus } from './dispatch.types';
import { CreateDriverJobRecord, IDispatchRepository } from './dispatch.repository';

/**
 * Temporary in-memory store standing in for the Prisma-backed repository.
 * Swap for a PrismaDispatchRepository once schema.prisma exists —
 * DispatchService only depends on IDispatchRepository.
 */
export class InMemoryDispatchRepository implements IDispatchRepository {
  private readonly jobs = new Map<string, DriverJob>();

  async create(data: CreateDriverJobRecord): Promise<DriverJob> {
    const now = new Date();
    const job: DriverJob = { id: randomUUID(), ...data, status: 'PENDING', createdAt: now, updatedAt: now };
    this.jobs.set(job.id, job);
    return job;
  }

  async findById(id: string): Promise<DriverJob | null> {
    return this.jobs.get(id) ?? null;
  }

  async findAllForTransaction(transactionId: string): Promise<DriverJob[]> {
    return [...this.jobs.values()]
      .filter((job) => job.transactionId === transactionId)
      .sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime());
  }

  async findActiveForTransaction(transactionId: string): Promise<DriverJob | null> {
    return (
      [...this.jobs.values()].find(
        (job) => job.transactionId === transactionId && (job.status === 'PENDING' || job.status === 'ACCEPTED'),
      ) ?? null
    );
  }

  async findJobsForDriver(driverId: string, status?: DriverJobStatus): Promise<DriverJob[]> {
    return [...this.jobs.values()]
      .filter((job) => job.driverId === driverId && (!status || job.status === status))
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
  }

  async update(id: string, status: DriverJobStatus): Promise<DriverJob> {
    const existing = this.jobs.get(id);
    if (!existing) throw new NotFoundError('Driver job not found');
    const updated: DriverJob = { ...existing, status, updatedAt: new Date() };
    this.jobs.set(id, updated);
    return updated;
  }
}

export const dispatchRepository = new InMemoryDispatchRepository();
