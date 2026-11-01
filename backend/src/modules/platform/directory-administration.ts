type Admin = { id: bigint; fullName: string; status: string };
type Invitation = { acceptedAt: Date | null; acceptedUserId: bigint | null; expiresAt: Date };

export function directoryAdministration(status: string, admins: Admin[], invitation?: Invitation | null, now = new Date()) {
  const acceptedAdmin = invitation?.acceptedUserId == null ? undefined
    : admins.find(admin => admin.id === invitation.acceptedUserId);
  const invitationStatus = !invitation ? 'NOT_ISSUED'
    : invitation.acceptedAt
      ? !acceptedAdmin ? 'REVIEW_REQUIRED'
        : status === 'PENDING_ACTIVATION' && acceptedAdmin.status === 'DISABLED'
          ? 'AWAITING_ACTIVATION' : 'ACCEPTED'
      : invitation.expiresAt <= now ? 'EXPIRED' : 'AWAITING_ACCEPTANCE';
  return {
    adminAccounts: admins.map(admin => ({ fullName: admin.fullName, status: admin.status })),
    invitationStatus,
  };
}
