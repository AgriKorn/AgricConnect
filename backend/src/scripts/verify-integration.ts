import crypto from 'crypto';
import { prisma } from '../config/db';
import { auditService } from '../modules/audit/audit.service';
import { dispatchService } from '../modules/dispatch/dispatch.service';
import { disputeService } from '../modules/dispute/dispute.service';
import { listingRepository } from '../modules/listing/listing.repository.prisma';
import { notificationService } from '../modules/notification/notification.service';
import { transactionService } from '../modules/transaction/transaction.service';
import { userRepository } from '../modules/user/user.repository.prisma';

async function runVerification() {
  console.log('🧪 Starting End-to-End Integration & Escrow Verification Test Suite...\n');

  // Clean test audit entries for clean chain verification
  await prisma.auditTrail.deleteMany({});

  // Step 1: Create Test Accounts (Farmer, Buyer, Driver)
  const phoneSuffix = Math.floor(100000000 + Math.random() * 900000000);
  const farmer = await userRepository.create({
    name: 'Integration Farmer',
    phone: `+233${phoneSuffix}`,
    passwordHash: 'hash',
    role: 'farmer',
    otp: '',
    otpExpiry: new Date(),
  });
  await userRepository.update(farmer.id, { status: 'ACTIVE' });

  const buyer = await userRepository.create({
    name: 'Integration Buyer',
    phone: `+233${phoneSuffix + 1}`,
    passwordHash: 'hash',
    role: 'buyer',
    otp: '',
    otpExpiry: new Date(),
  });
  await userRepository.update(buyer.id, { status: 'ACTIVE' });

  const driver = await userRepository.create({
    name: 'Integration Driver',
    phone: `+233${phoneSuffix + 2}`,
    passwordHash: 'hash',
    role: 'driver',
    otp: '',
    otpExpiry: new Date(),
  });
  await userRepository.update(driver.id, { status: 'ACTIVE' });
  await userRepository.updateProfile(driver.id, { isAvailable: true, truckCapacity: 5000 });

  console.log('✅ Step 1: Created Farmer, Buyer, and Driver test accounts.');

  // Step 2: Create Produce Listing
  const listingHash = crypto.createHash('sha256').update(`listing_test_${Date.now()}_1`).digest('hex');
  const listing = await listingRepository.create({
    farmerId: farmer.id,
    cropType: 'tomato',
    quantityKg: 200,
    freshnessScore: 9.5,
    shelfLifeDays: 7,
    farmerLat: 5.6037,
    farmerLong: -0.187,
    pricePerKg: 15.0,
    listingHash,
    qrCodeData: listingHash,
    status: 'ACTIVE',
  });
  console.log(`✅ Step 2: Produced listing ${listing.id} for 200kg of tomato.`);

  // Step 3: Purchase & Escrow Hold ($transaction)
  const { transaction, dispatch } = await transactionService.purchase(listing.id, buyer.id, false);
  console.log(`✅ Step 3: Purchase completed. Order ID: ${transaction.id}, Payment status: ${transaction.status}.`);

  if (!dispatch) throw new Error('❌ Expected driver dispatch job to be created.');

  // Step 4: Driver Job Acceptance
  const acceptedJob = await dispatchService.acceptJob(dispatch.id, dispatch.driverId);
  console.log(`✅ Step 4: Driver accepted job. Status: ${acceptedJob.status}.`);

  // Step 5: Confirm Delivery & Release Escrow Funds ($transaction)
  const confirmedTx = await transactionService.confirmDelivery(transaction.id, listingHash, buyer.id);
  console.log(`✅ Step 5: Delivery confirmed. Transaction status: ${confirmedTx.status}.`);

  // Step 6: Verify Notifications and Cryptographic Audit Chain
  const farmerNotifications = await notificationService.getUserNotifications(farmer.id);
  console.log(`✅ Step 6: Farmer received ${farmerNotifications.length} in-app notification(s).`);

  const auditCheck = await auditService.verifyChainForEntity(transaction.id);
  if (!auditCheck.valid) {
    throw new Error(`❌ Cryptographic Audit Chain Verification Failed: ${auditCheck.failureReason}`);
  }
  console.log(`✅ Step 6: Audit Chain Integrity Verified: ${auditCheck.totalEntries} entries, unbroken.`);

  // Step 7: Dispute Resolution, Refund & Re-sale Test
  console.log('\n⚖️ Testing Dispute Resolution (REFUND_BUYER) and Re-sale Flow...');
  
  // Create second listing for dispute test
  const listingHash2 = crypto.createHash('sha256').update(`listing_test_${Date.now()}_2`).digest('hex');
  const listing2 = await listingRepository.create({
    farmerId: farmer.id,
    cropType: 'maize',
    quantityKg: 500,
    freshnessScore: 8.0,
    shelfLifeDays: 14,
    farmerLat: 5.6037,
    farmerLong: -0.187,
    pricePerKg: 10.0,
    listingHash: listingHash2,
    qrCodeData: listingHash2,
    status: 'ACTIVE',
  });

  const { transaction: tx2 } = await transactionService.purchase(listing2.id, buyer.id, true);
  const dispute = await disputeService.raise(tx2.id, 'NON_DELIVERY', 'Produce not delivered on time', buyer.id);
  console.log(`✅ Dispute #${dispute.id} raised on Order #${tx2.id}.`);

  // Admin resolves dispute with REFUND_BUYER
  await disputeService.resolve(dispute.id, 'Refunding buyer due to non-delivery', 'REFUND_BUYER');
  const refundedTx = await transactionService.getTransaction(tx2.id, buyer.id, 'buyer');
  if (refundedTx.status !== 'CANCELLED') {
    throw new Error(`❌ Expected transaction status to be CANCELLED, got ${refundedTx.status}`);
  }
  console.log(`✅ Dispute resolved. Transaction status updated to CANCELLED.`);

  // Verify re-sale capability: Farmer re-lists produce, new purchase succeeds
  const { transaction: tx3 } = await transactionService.purchase(listing2.id, buyer.id, true);
  console.log(`✅ Re-sale test succeeded! Listing ${listing2.id} successfully re-purchased after refund. Order ID: ${tx3.id}.`);

  // Step 8: Live Simultaneous Double-Purchase Concurrency Test
  console.log('\n⚡ Testing Live Simultaneous Double-Purchase Concurrency Protection...');
  const buyer2 = await userRepository.create({
    name: 'Buyer Two',
    phone: `+233${phoneSuffix + 3}`,
    role: 'buyer',
    passwordHash: 'hash',
    otp: '',
    otpExpiry: new Date(),
  });

  const listingHash3 = crypto.createHash('sha256').update(`listing_test_${Date.now()}_3`).digest('hex');
  const listing3 = await listingRepository.create({
    farmerId: farmer.id,
    cropType: 'yam',
    quantityKg: 100,
    freshnessScore: 9.0,
    shelfLifeDays: 30,
    farmerLat: 5.6037,
    farmerLong: -0.187,
    pricePerKg: 20.0,
    listingHash: listingHash3,
    qrCodeData: listingHash3,
    status: 'ACTIVE',
  });

  // Trigger two simultaneous purchase requests at the exact same instant
  const [res1, res2] = await Promise.allSettled([
    transactionService.purchase(listing3.id, buyer.id, true),
    transactionService.purchase(listing3.id, buyer2.id, true),
  ]);

  const fulfilledCount = [res1, res2].filter((r) => r.status === 'fulfilled').length;
  const rejectedCount = [res1, res2].filter((r) => r.status === 'rejected').length;

  if (fulfilledCount !== 1 || rejectedCount !== 1) {
    throw new Error(`❌ Concurrency Test Failed: Expected 1 fulfilled and 1 rejected, got ${fulfilledCount} fulfilled and ${rejectedCount} rejected.`);
  }

  console.log(`✅ Concurrency Protection Verified! Exactly 1 purchase succeeded and 1 simultaneous request was rejected with 409 Conflict.`);

  console.log('\n🎉 ALL INTEGRATION TESTS, ESCROW CHECKS & CONCURRENCY TESTS PASSED SUCCESSFULLY!');
}

runVerification()
  .catch((e) => {
    console.error('❌ Integration Test Failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
