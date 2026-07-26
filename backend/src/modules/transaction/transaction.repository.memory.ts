import { randomUUID } from 'crypto';
import { NotFoundError } from '../../utils/errors';
import { Transaction } from './transaction.types';
import { CreateTransactionRecord, isActiveStatus, ITransactionRepository } from './transaction.repository';

/**
 * Temporary in-memory store standing in for the Prisma-backed repository.
 * Swap for a PrismaTransactionRepository once schema.prisma exists —
 * TransactionService only depends on ITransactionRepository.
 */
export class InMemoryTransactionRepository implements ITransactionRepository {
  private readonly transactions = new Map<string, Transaction>();

  async create(data: CreateTransactionRecord): Promise<Transaction> {
    const now = new Date();
    const transaction: Transaction = {
      id: randomUUID(),
      ...data,
      status: 'PAYMENT_HELD',
      transferCode: null,
      createdAt: now,
      updatedAt: now,
    };
    this.transactions.set(transaction.id, transaction);
    return transaction;
  }

  async findById(id: string): Promise<Transaction | null> {
    return this.transactions.get(id) ?? null;
  }

  async findActiveByListingId(listingId: string): Promise<Transaction | null> {
    return (
      [...this.transactions.values()].find((t) => t.listingId === listingId && isActiveStatus(t.status)) ?? null
    );
  }

  async findManyForUser(userId: string): Promise<Transaction[]> {
    return [...this.transactions.values()]
      .filter((t) => t.buyerId === userId || t.farmerId === userId)
      .sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
  }

  async findAll(): Promise<Transaction[]> {
    return [...this.transactions.values()].sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
  }

  async update(id: string, data: Partial<Pick<Transaction, 'status' | 'transferCode'>>): Promise<Transaction> {
    const existing = this.transactions.get(id);
    if (!existing) throw new NotFoundError('Transaction not found');
    const updated: Transaction = { ...existing, ...data, updatedAt: new Date() };
    this.transactions.set(id, updated);
    return updated;
  }
}

export const transactionRepository = new InMemoryTransactionRepository();
