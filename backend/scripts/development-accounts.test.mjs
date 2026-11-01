import test from 'node:test';
import assert from 'node:assert/strict';
import bcrypt from 'bcryptjs';
import { ensureDevelopmentAccounts, validateDemoAccounts, coreDemoAccounts } from './development-accounts.mjs';

const accounts = [
  ['superadmin@afaq.test', 'SUPER_ADMIN'], ['reviewer@afaq.test', 'SUPER_ADMIN'],
  ['it@afaq.test', 'IT_SECURITY'], ['schooladmin@afaq.test', 'ADMIN'],
  ['parent@afaq.test', 'PARENT'], ['quran.teacher@afaq.test', 'TEACHER'],
].map(([email, role]) => ({ email, role, password: 'Synthetic-test-only-123!' }));

test('validates the six expected synthetic identities', () => assert.equal(validateDemoAccounts(accounts).length, 6));
test('unified directory includes teacher once and preserves legacy preparation', () => {
  assert.deepEqual(coreDemoAccounts([...accounts, { email: 'synthetic@example.test', role: 'ACCOUNTANT' }], accounts[5]), accounts);
  assert.deepEqual(coreDemoAccounts(accounts.slice(0, 5), accounts[5]), accounts);
  assert.throws(() => coreDemoAccounts([...accounts, accounts[5]], accounts[5]));
});
test('rejects missing identities', () => assert.throws(() => validateDemoAccounts(accounts.slice(1))));
test('rejects duplicate identities', () => assert.throws(() => validateDemoAccounts([...accounts.slice(1), accounts[1]])));
test('rejects changing a school account into a privileged role', () => {
  assert.throws(() => validateDemoAccounts(accounts.map(row => row.role === 'TEACHER' ? { ...row, role: 'SUPER_ADMIN' } : row)));
});

async function existingDb(disabled = false) {
  const hash = await bcrypt.hash(accounts[0].password, 4);
  const lookup = email => ({ ...accounts.find(row => row.email === email), status: disabled ? 'DISABLED' : 'ACTIVE', passwordHash: hash });
  const create = () => { throw new Error('Existing records must not be rewritten'); };
  const tx = {
    organization: { findUnique: async () => ({ id: 1n, status: 'ACTIVE' }) },
    branch: { findFirst: async () => ({ id: 1n }) },
    platformAccount: { findUnique: async ({ where }) => lookup(where.email), create, update: create, upsert: create },
    user: { findUnique: async ({ where }) => lookup(where.orgId_email.email), create, update: create, upsert: create },
  };
  return { $transaction: async callback => callback(tx) };
}
test('rerunning preparation preserves every existing account and password', async () => {
  assert.deepEqual(await ensureDevelopmentAccounts(await existingDb(), accounts), { created: 0, preserved: 6 });
});
test('never re-enables an existing disabled account', async () => {
  await assert.rejects(ensureDevelopmentAccounts(await existingDb(true), accounts), /No account was overwritten/);
});
test('never resets an existing password to match a credential file', async () => {
  const changed = accounts.map(row => ({ ...row, password: 'Different-synthetic-password!' }));
  await assert.rejects(ensureDevelopmentAccounts(await existingDb(), changed), /No account was overwritten/);
});
