import { DriverJob, DriverJobStatus } from './dispatch.types';

export type CreateDriverJobRecord = Pick<DriverJob, 'transactionId' | 'listingId' | 'driverId' | 'cropType' | 'quantityKg'>;

export interface IDispatchRepository {
  create(data: CreateDriverJobRecord): Promise<DriverJob>;
  findById(id: string): Promise<DriverJob | null>;
  findAllForTransaction(transactionId: string): Promise<DriverJob[]>;
  findActiveForTransaction(transactionId: string): Promise<DriverJob | null>;
  update(id: string, status: DriverJobStatus): Promise<DriverJob>;
}
