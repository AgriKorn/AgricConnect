import axios from 'axios';

const LIVE_API_BASE = 'https://container-service-1.veg2jxqsfecbm.eu-west-1.cs.amazonlightsail.com/api';

interface TestResult {
  category: string;
  testName: string;
  endpoint: string;
  expectedStatus: number;
  actualStatus: number;
  passed: boolean;
  notes: string;
}

const testResults: TestResult[] = [];

function recordResult(
  category: string,
  testName: string,
  endpoint: string,
  expectedStatus: number,
  actualStatus: number,
  notes: string
) {
  const passed = actualStatus === expectedStatus;
  testResults.push({
    category,
    testName,
    endpoint,
    expectedStatus,
    actualStatus,
    passed,
    notes,
  });
  const symbol = passed ? '✅ PASS' : '❌ FAIL';
  console.log(`[${symbol}] ${category} :: ${testName}`);
  console.log(`  └─ Endpoint: ${endpoint} | Expected: ${expectedStatus} | Actual: ${actualStatus}`);
  console.log(`  └─ Notes: ${notes}\n`);
}

async function runSuite1() {
  console.log('======================================================================');
  console.log('🚀 EXECUTING SUITE 1: REST API CONTRACT, BOUNDARY & EDGE-CASE TESTS');
  console.log(` Target API Base URL: ${LIVE_API_BASE}`);
  console.log('======================================================================\n');

  // 1. Health Check Test
  try {
    const res = await axios.get(`${LIVE_API_BASE}/health`);
    recordResult('Health Check', 'System Health Ping', 'GET /health', 200, res.status, `Message: ${JSON.stringify(res.data)}`);
  } catch (err: any) {
    const status = err.response?.status || 500;
    recordResult('Health Check', 'System Health Ping', 'GET /health', 200, status, err.message);
  }

  // 2. Auth: Registration Validation - Missing Fields
  try {
    await axios.post(`${LIVE_API_BASE}/auth/register`, { name: 'Test Missing' });
    recordResult('Auth Boundary', 'Register with Missing Fields', 'POST /auth/register', 400, 200, 'FAILED: Accepted invalid payload');
  } catch (err: any) {
    const status = err.response?.status || 500;
    recordResult('Auth Boundary', 'Register with Missing Fields', 'POST /auth/register', 400, status, 'Correctly rejected missing fields with 400 Bad Request');
  }

  // 3. Auth: Registration Validation - Invalid Role ("superadmin")
  try {
    await axios.post(`${LIVE_API_BASE}/auth/register`, {
      phone: '+233240001999',
      name: 'Hacker User',
      password: 'Password123!',
      role: 'superadmin',
    });
    recordResult('Auth Boundary', 'Register with Invalid Role', 'POST /auth/register', 400, 200, 'FAILED: Allowed invalid role');
  } catch (err: any) {
    const status = err.response?.status || 500;
    recordResult('Auth Boundary', 'Register with Invalid Role', 'POST /auth/register', 400, status, 'Correctly rejected invalid role with 400 Bad Request');
  }

  // 4. Auth: Registration Validation - Valid Buyer Registration
  const testBuyerPhone = `+23324${Math.floor(1000000 + Math.random() * 9000000)}`;
  let buyerToken = '';
  try {
    const res = await axios.post(`${LIVE_API_BASE}/auth/register`, {
      phone: testBuyerPhone,
      name: 'QA Auto Buyer',
      password: 'Password123!',
      role: 'buyer',
    });
    buyerToken = res.data.token || res.data.data?.token || res.data.accessToken || res.data.data?.accessToken;
    recordResult('Auth Contract', 'Valid Buyer Registration', 'POST /auth/register', 201, res.status, `Registered Buyer Account successfully`);
  } catch (err: any) {
    const status = err.response?.status || 500;
    recordResult('Auth Contract', 'Valid Buyer Registration', 'POST /auth/register', 201, status, err.response?.data?.message || err.message);
  }

  // 5. Auth: Security Guard - Unapproved User Pending Login Defense
  const testFarmerPhone = `+23324${Math.floor(1000000 + Math.random() * 9000000)}`;
  try {
    await axios.post(`${LIVE_API_BASE}/auth/register`, {
      phone: testFarmerPhone,
      name: 'QA Unapproved Farmer',
      password: 'Password123!',
      role: 'farmer',
    });
    await axios.post(`${LIVE_API_BASE}/auth/login`, {
      phone: testFarmerPhone,
      password: 'Password123!',
    });
    recordResult('Auth Security', 'Unapproved User Login Defense', 'POST /auth/login', 403, 200, 'FAILED: Allowed login for unapproved user');
  } catch (err: any) {
    const status = err.response?.status || 500;
    recordResult('Auth Security', 'Unapproved User Login Defense', 'POST /auth/login', 403, status, 'Correctly enforced 403 Forbidden until Admin approval');
  }

  // 6. Auth: Registration Validation - Duplicate Phone Number
  try {
    await axios.post(`${LIVE_API_BASE}/auth/register`, {
      phone: testBuyerPhone,
      name: 'Duplicate Buyer',
      password: 'Password123!',
      role: 'buyer',
    });
    recordResult('Auth Boundary', 'Register Duplicate Phone', 'POST /auth/register', 409, 200, 'FAILED: Allowed duplicate phone');
  } catch (err: any) {
    const status = err.response?.status || 500;
    recordResult('Auth Boundary', 'Register Duplicate Phone', 'POST /auth/register', 409, status, 'Correctly threw 409 Conflict');
  }

  // 7. Auth: Login Validation - Invalid Password
  try {
    await axios.post(`${LIVE_API_BASE}/auth/login`, {
      phone: testBuyerPhone,
      password: 'WrongPassword123!',
    });
    recordResult('Auth Boundary', 'Login Bad Credentials', 'POST /auth/login', 401, 200, 'FAILED: Allowed invalid login');
  } catch (err: any) {
    const status = err.response?.status || 500;
    recordResult('Auth Boundary', 'Login Bad Credentials', 'POST /auth/login', 401, status, 'Correctly threw 401 Unauthorized');
  }

  // 8. Listings: Security Guard - Access Without JWT Token
  try {
    await axios.get(`${LIVE_API_BASE}/listings`);
    recordResult('Listings Security', 'GET /listings without Auth', 'GET /listings', 401, 200, 'FAILED: Exposed endpoint without token');
  } catch (err: any) {
    const status = err.response?.status || 500;
    recordResult('Listings Security', 'GET /listings without Auth', 'GET /listings', 401, status, 'Correctly protected with 401 Unauthorized');
  }

  // 9. Payments: Security Guard - Paystack Account Resolve Without Token
  try {
    await axios.get(`${LIVE_API_BASE}/payments/paystack/resolve-momo?accountNumber=0241234567&bankCode=MTN`);
    recordResult('Payment Security', 'Resolve MoMo without Auth', 'GET /payments/paystack/resolve-momo', 401, 200, 'FAILED: Unprotected MoMo resolve');
  } catch (err: any) {
    const status = err.response?.status || 500;
    recordResult('Payment Security', 'Resolve MoMo without Auth', 'GET /payments/paystack/resolve-momo', 401, status, 'Correctly rejected with 401 Unauthorized');
  }

  // Summary Report Output
  const total = testResults.length;
  const passedCount = testResults.filter((r) => r.passed).length;
  const failedCount = total - passedCount;

  console.log('======================================================================');
  console.log(`📊 SUITE 1 SUMMARY: ${passedCount}/${total} TESTS PASSED (${failedCount} FAILURES)`);
  console.log('======================================================================');
}

runSuite1().catch(console.error);
