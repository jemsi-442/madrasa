const auditActionLabels = {
  '': 'All events',
  'tenant.technical-review.recorded': 'IT sign-off recorded',
  'tenant.technical-review.withdrawn': 'IT sign-off withdrawn',
  'platform.login.failed': 'Failed login',
  'platform.audit.exported': 'Audit PDF generated',
  'platform.login.succeeded': 'Successful login',
  'tenant.application.requested': 'Madrassa requested',
  'tenant.application.approved': 'Madrassa approved',
  'tenant.application.rejected': 'Madrassa rejected',
  'tenant.school.provisioned': 'Inactive madrassa created',
  'tenant.admin.invitation.issued': 'Admin invitation recorded',
  'tenant.school.activated': 'Madrassa activated',
  'platform.session.revoked': 'Session revoked',
  'platform.sessions.revoked': 'All sessions revoked',
  'platform.account.bootstrapped': 'Reviewer created',
  'platform.account.disabled': 'IT account disabled',
  'platform.account.restored': 'IT account restored',
};

String auditActionLabel(dynamic value) =>
    auditActionLabels[value] ?? value?.toString() ?? 'Not recorded';

String auditRoleLabel(dynamic value) => switch (value) {
  'IT_SECURITY' => 'IT / Security',
  'SUPER_ADMIN' => 'Super Admin',
  null => 'Not recorded',
  _ => value.toString(),
};

String auditReferenceLabel(dynamic value) => switch (value) {
  'PlatformAccount' => 'Platform account',
  'AuditExport' => 'Audit export',
  null => 'Not recorded',
  _ => value.toString(),
};
