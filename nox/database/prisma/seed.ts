// Run from nox/backend:  npm run prisma:seed
// (the script sets NODE_PATH so '@prisma/client' and 'bcrypt' resolve from
//  nox/backend/node_modules — this directory has no node_modules of its own)
import { PrismaClient } from '@prisma/client';
import * as bcrypt from 'bcrypt';

const prisma = new PrismaClient();

// Must match the cost used by AuthService / UsersService.
const BCRYPT_ROUNDS = 12;

const ROLES = [
  { name: 'SUPER_ADMIN', description: 'Full system access' },
  { name: 'ADMIN', description: 'Administrative access' },
  { name: 'SUPPORT', description: 'Support agent access' },
  { name: 'ORG_ADMIN', description: 'Organization admin access' },
  { name: 'USER', description: 'Standard user access' },
] as const;

type RoleName = (typeof ROLES)[number]['name'];

const PERMISSIONS = [
  { name: 'users:read', resource: 'users', action: 'read', description: 'View users' },
  { name: 'users:write', resource: 'users', action: 'write', description: 'Manage users' },
  { name: 'users:delete', resource: 'users', action: 'delete', description: 'Delete users' },
  { name: 'devices:read', resource: 'devices', action: 'read', description: 'View devices' },
  { name: 'devices:write', resource: 'devices', action: 'write', description: 'Manage devices' },
  { name: 'devices:delete', resource: 'devices', action: 'delete', description: 'Delete devices' },
  { name: 'files:read', resource: 'files', action: 'read', description: 'View files' },
  { name: 'files:write', resource: 'files', action: 'write', description: 'Manage files' },
  { name: 'files:delete', resource: 'files', action: 'delete', description: 'Delete files' },
  { name: 'notifications:read', resource: 'notifications', action: 'read', description: 'View notifications' },
  { name: 'notifications:write', resource: 'notifications', action: 'write', description: 'Send notifications' },
  { name: 'messages:read', resource: 'messages', action: 'read', description: 'View messages' },
  { name: 'messages:write', resource: 'messages', action: 'write', description: 'Send messages' },
  { name: 'sessions:read', resource: 'sessions', action: 'read', description: 'View sessions' },
  { name: 'sessions:write', resource: 'sessions', action: 'write', description: 'Manage sessions' },
  { name: 'audit:read', resource: 'audit', action: 'read', description: 'View audit logs' },
  { name: 'admin:access', resource: 'admin', action: 'access', description: 'Access admin panel' },
  { name: 'support:access', resource: 'support', action: 'access', description: 'Access support' },
  { name: 'screen:view', resource: 'screen', action: 'view', description: 'View screen mirror' },
  { name: 'screen:control', resource: 'screen', action: 'control', description: 'Remote control' },
] as const;

type PermissionName = (typeof PERMISSIONS)[number]['name'];

const ALL_PERMISSIONS: PermissionName[] = PERMISSIONS.map((p) => p.name);

// Baseline permissions every authenticated user gets for their own resources.
const USER_PERMISSIONS: PermissionName[] = [
  'devices:read', 'devices:write', 'devices:delete',
  'files:read', 'files:write', 'files:delete',
  'notifications:read',
  'messages:read', 'messages:write',
  'sessions:read', 'sessions:write',
  'screen:view', 'screen:control',
];

const ROLE_PERMISSIONS: Record<RoleName, PermissionName[]> = {
  SUPER_ADMIN: ALL_PERMISSIONS,
  ADMIN: [
    ...USER_PERMISSIONS,
    'users:read', 'users:write', 'users:delete',
    'notifications:write',
    'audit:read',
    'admin:access',
    'support:access',
  ],
  SUPPORT: [
    'users:read',
    'devices:read',
    'files:read',
    'notifications:read', 'notifications:write',
    'messages:read', 'messages:write',
    'sessions:read',
    'support:access',
    'screen:view',
  ],
  ORG_ADMIN: [
    ...USER_PERMISSIONS,
    'users:read', 'users:write',
    'notifications:write',
    'audit:read',
  ],
  USER: USER_PERMISSIONS,
};

const PORTALS = [
  { name: 'Admin Portal', slug: 'admin' },
  { name: 'Support Portal', slug: 'support' },
  { name: 'Business Portal', slug: 'business' },
  { name: 'Analytics Portal', slug: 'analytics' },
  { name: 'Super Admin Portal', slug: 'super-admin' },
];

async function main() {
  console.log('🌱 Seeding NOX database...');

  // ── Roles ──
  const roleIds = {} as Record<RoleName, string>;
  for (const role of ROLES) {
    const r = await prisma.role.upsert({
      where: { name: role.name },
      update: { description: role.description, isSystem: true },
      create: { name: role.name, description: role.description, isSystem: true },
    });
    roleIds[role.name] = r.id;
  }

  // ── Permissions ──
  const permissionIds = {} as Record<PermissionName, string>;
  for (const perm of PERMISSIONS) {
    const p = await prisma.permission.upsert({
      where: { name: perm.name },
      update: { resource: perm.resource, action: perm.action, description: perm.description },
      create: perm,
    });
    permissionIds[perm.name] = p.id;
  }

  // ── Role → Permission assignments (idempotent) ──
  for (const [roleName, perms] of Object.entries(ROLE_PERMISSIONS) as [RoleName, PermissionName[]][]) {
    const roleId = roleIds[roleName];
    const { count } = await prisma.rolePermission.createMany({
      data: [...new Set(perms)].map((name) => ({ roleId, permissionId: permissionIds[name] })),
      skipDuplicates: true,
    });
    console.log(`  ${roleName}: ${perms.length} permissions (${count} new)`);
  }

  // ── Portals ──
  for (const portal of PORTALS) {
    await prisma.portal.upsert({
      where: { slug: portal.slug },
      update: {},
      create: portal,
    });
  }

  // ── Super admin user ──
  const adminEmail = process.env.SEED_ADMIN_EMAIL ?? 'admin@nox.dev';
  let adminPassword = process.env.SEED_ADMIN_PASSWORD;
  if (!adminPassword) {
    if (process.env.NODE_ENV === 'production') {
      throw new Error('SEED_ADMIN_PASSWORD must be set when seeding in production');
    }
    adminPassword = 'NoxAdmin@2024';
    console.warn('⚠️  SEED_ADMIN_PASSWORD not set — using development default password. Change it after first login.');
  }

  // Never store the plaintext; hash with bcrypt (same cost as the auth service).
  const passwordHash = await bcrypt.hash(adminPassword, BCRYPT_ROUNDS);

  // Existing admin keeps its current password (update: {}) so re-seeding
  // never silently resets a changed password.
  const superAdmin = await prisma.user.upsert({
    where: { email: adminEmail },
    update: {},
    create: {
      email: adminEmail,
      passwordHash,
      firstName: 'NOX',
      lastName: 'Admin',
      emailVerified: true,
    },
  });

  await prisma.userRole.upsert({
    where: { userId_roleId: { userId: superAdmin.id, roleId: roleIds.SUPER_ADMIN } },
    update: {},
    create: { userId: superAdmin.id, roleId: roleIds.SUPER_ADMIN },
  });

  console.log(`✅ Seed complete (super admin: ${adminEmail})`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
