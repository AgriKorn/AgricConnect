import bcrypt from 'bcryptjs';

const hash = '$2b$10$Cv/cfZ8K.jXxZxmdT8uOT.HK8uBV8zyW.TAYFsOw4xcsv6dEKUPJC';
const candidates = [
  'Password123!',
  'TestPassword123!',
  'TestPass123!',
  'admin12345',
  'farmer12345',
  'buyer12345',
  'password123',
  'Password123'
];

for (const p of candidates) {
  if (bcrypt.compareSync(p, hash)) {
    console.log(`MATCH FOUND: "${p}"`);
  }
}
process.exit(0);
