import bcrypt from 'bcryptjs';

const names = {
  'superadmin@afaq.test': ['SUPER_ADMIN', 'Demo Super Admin'],
  'reviewer@afaq.test': ['SUPER_ADMIN', 'Demo Office Reviewer'],
  'it@afaq.test': ['IT_SECURITY', 'Demo IT Officer'],
  'schooladmin@afaq.test': ['ADMIN', 'Demo School Admin'],
  'parent@afaq.test': ['PARENT', 'Demo Family Parent'],
  'quran.teacher@afaq.test': ['TEACHER', 'Demo Quran Teacher'],
};

export function validateDemoAccounts(rows) {
  if (!Array.isArray(rows) || rows.length !== 6 || new Set(rows.map(row => row?.email)).size !== 6 ||
      rows.some(row => !row || !names[row.email] || names[row.email][0] !== row.role ||
        typeof row.password !== 'string' || row.password.length < 12 || row.password.length > 72)) {
    throw new Error('Private demo account files are incomplete or invalid.');
  }
  return rows;
}

export function coreDemoAccounts(rows, teacher) {
  if (!Array.isArray(rows)) throw new Error('Invalid demo account list.');
  const core = rows.filter(row => row && Object.hasOwn(names, row.email));
  if (!core.some(row => row.email === 'quran.teacher@afaq.test')) core.push(teacher);
  return validateDemoAccounts(core);
}

export async function ensureDevelopmentAccounts(db, rows) {
  validateDemoAccounts(rows);
  return db.$transaction(async tx => {
    let created = 0, preserved = 0;
    const org = await tx.organization.findUnique({ where: { code: 'demo-madrasa' } });
    if (!org || org.status !== 'ACTIVE') throw new Error('The existing active demo-madrasa organization is required.');
    const branch = await tx.branch.findFirst({ where: { orgId: org.id }, orderBy: { id: 'asc' } });
    if (!branch) throw new Error('Existing demo branch is required.');
    for (const row of rows) {
      const [role, fullName] = names[row.email];
      const platform = ['SUPER_ADMIN', 'IT_SECURITY'].includes(role);
      const existing = platform
        ? await tx.platformAccount.findUnique({ where: { email: row.email } })
        : await tx.user.findUnique({ where: { orgId_email: { orgId: org.id, email: row.email } } });
      if (existing) {
        // Do not change passwords, roles, scopes or account status on rerun.
        if (existing.role !== role || existing.status !== 'ACTIVE' ||
            !await bcrypt.compare(row.password, existing.passwordHash)) {
          throw new Error('An existing demo account differs from the saved credentials. No account was overwritten.');
        }
        preserved++;
        continue;
      }
      const passwordHash = await bcrypt.hash(row.password, 12);
      if (platform) {
        const account = await tx.platformAccount.create({ data: { email: row.email, fullName, role, status: 'ACTIVE', passwordHash } });
        await tx.platformAuditEvent.create({ data: { actorId: account.id, actorRole: role,
          action: 'platform.account.development-created', entityType: 'PlatformAccount', entityId: account.id } });
      } else {
        const user = await tx.user.create({ data: { orgId: org.id, branchId: branch.id, email: row.email, fullName, role, status: 'ACTIVE', passwordHash } });
        if (role === 'PARENT') await tx.guardian.create({ data: { orgId: org.id, userId: user.id, fullName, email: row.email, phone: '255700000100' } });
      }
      created++;
    }
    return { created, preserved };
  }, { timeout: 30_000 });
}
