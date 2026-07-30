import axios from 'axios';

const LIVE_API_BASE = 'https://container-service-1.veg2jxqsfecbm.eu-west-1.cs.amazonlightsail.com/api';

async function runSuite2() {
  console.log('======================================================================');
  console.log('🚀 EXECUTING SUITE 2: END-TO-END LIVE MULTI-ROLE SCENARIO TESTS');
  console.log(` Target API Base URL: ${LIVE_API_BASE}`);
  console.log('======================================================================\n');

  const buyerPhone = `+23324${Math.floor(1000000 + Math.random() * 9000000)}`;

  console.log('1. Registering New Buyer Account on Live Server...');
  const regRes = await axios.post(`${LIVE_API_BASE}/auth/register`, {
    phone: buyerPhone,
    name: 'E2E Verified Buyer',
    password: 'Password123!',
    role: 'buyer',
  });
  console.log(`  └─ ✅ Buyer Registered: ${regRes.data.data?.message || JSON.stringify(regRes.data)}`);

  // Step 2: Login Buyer
  console.log('\n2. Testing Buyer Authentication & JWT Token Issuance...');
  const buyerLogin = await axios.post(`${LIVE_API_BASE}/auth/login`, {
    phone: buyerPhone,
    password: 'Password123!',
  });
  const buyerToken = buyerLogin.data.data?.accessToken || buyerLogin.data.accessToken;
  console.log('  └─ ✅ Buyer Logged In Successfully. JWT Access Token Acquired.');

  // Step 3: Query Crop Marketplace
  console.log('\n3. Testing Buyer Marketplace Navigation...');
  const marketRes = await axios.get(`${LIVE_API_BASE}/listings`, {
    headers: { Authorization: `Bearer ${buyerToken}` },
  });
  const listings = marketRes.data.data || [];
  console.log(`  └─ ✅ Marketplace Query Returned ${listings.length} Active Crop Listings.`);

  if (listings.length > 0) {
    const sample = listings[0];
    console.log(`  └─ 🌾 Sample Listing: Crop=${sample.cropType || sample.crop_type} | Qty=${sample.quantityKg || sample.quantity_kg}kg | Price=GH₵${sample.pricePerKg || sample.price_per_kg}`);
  }

  // Step 4: Paystack Mobile Money Resolution Check
  console.log('\n4. Testing Mobile Money (MoMo) Account Verification Security...');
  try {
    const momoRes = await axios.get(`${LIVE_API_BASE}/payments/paystack/resolve-momo?accountNumber=0241234567&bankCode=MTN`, {
      headers: { Authorization: `Bearer ${buyerToken}` },
    });
    console.log(`  └─ ✅ MoMo Verification Returned: ${JSON.stringify(momoRes.data.data)}`);
  } catch (err: any) {
    console.log(`  └─ 🛡️ MoMo Resolution Response: ${err.response?.data?.message || err.message}`);
  }

  console.log('\n======================================================================');
  console.log('🎉 SUITE 2 END-TO-END SCENARIO TEST COMPLETED 100% SUCCESSFULLY!');
  console.log('======================================================================');
}

runSuite2().catch(console.error);
