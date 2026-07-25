import { Dispute } from './dispute.types';

export type CreateDisputeRecord = Pick<Dispute, 'transactionId' | 'raisedBy' | 'type' | 'description'>;

export interface IDisputeRepository {
  create(data: CreateDisputeRecord): Promise<Dispute>;
  findById(id: string): Promise<Dispute | null>;
  findAll(): Promise<Dispute[]>;
  resolve(id: string, resolution: string): Promise<Dispute>;
}
