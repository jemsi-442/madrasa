import { expect, it } from 'vitest';
import { directoryAdministration } from '../src/modules/platform/directory-administration';

const now = new Date('2026-10-30T12:00:00Z');
const admin = { id: 3n, fullName: 'Synthetic Admin', status: 'DISABLED' };
const invitation = { acceptedAt: null, acceptedUserId: null, expiresAt: new Date(now.getTime() + 1000) };
it('reports absent, pending and expired invitations without inventing delivery', () => {
  expect(directoryAdministration('PENDING_ACTIVATION', [], null, now).invitationStatus).toBe('NOT_ISSUED');
  expect(directoryAdministration('PENDING_ACTIVATION', [], invitation, now).invitationStatus).toBe('AWAITING_ACCEPTANCE');
  expect(directoryAdministration('PENDING_ACTIVATION', [], { ...invitation, expiresAt: now }, now).invitationStatus).toBe('EXPIRED');
});
it('only reports pending activation for a matching accepted disabled administrator', () => {
  const accepted = { ...invitation, acceptedAt: now, acceptedUserId: 3n };
  expect(directoryAdministration('PENDING_ACTIVATION', [admin], accepted, now).invitationStatus).toBe('AWAITING_ACTIVATION');
  expect(directoryAdministration('SUSPENDED', [admin], accepted, now).invitationStatus).toBe('ACCEPTED');
  expect(directoryAdministration('PENDING_ACTIVATION', [], accepted, now).invitationStatus).toBe('REVIEW_REQUIRED');
});
it('keeps account status separate and returns no ids or invitation secrets', () => {
  const result = directoryAdministration('SUSPENDED', [admin, { ...admin, id: 4n, status: 'ACTIVE' }]);
  expect(result.adminAccounts).toEqual([
    { fullName: 'Synthetic Admin', status: 'DISABLED' },
    { fullName: 'Synthetic Admin', status: 'ACTIVE' },
  ]);
  expect(Object.keys(result).sort()).toEqual(['adminAccounts', 'invitationStatus']);
});
