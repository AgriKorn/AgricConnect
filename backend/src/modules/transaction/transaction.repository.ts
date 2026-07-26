import { Transaction, TransactionStatus } from './transaction.types';

export type CreateTransactionRecord = Pick<
  Transaction,
  'listingId' | 'buyerId' | 'farmerId' | 'amountGhs' | 'hasOwnTransport' | 'paymentReference'
>;

export interface ITransactionRepository {
  create(data: CreateTransactionRecord): Promise<Transaction>;
  findById(id: string): Promise<Transaction | null>;
  findActiveByListingId(listingId: string): Promise<Transaction | null>;
  findManyForUser(userId: string): Promise<Transaction[]>;
  findAll(): Promise<Transaction[]>;
  update(id: string, data: Partial<Pick<Transaction, 'status' | 'transferCode'>>): Promise<Transaction>;
}

export const isActiveStatus = (status: TransactionStatus): boolean => status === 'PAYMENT_HELD';
