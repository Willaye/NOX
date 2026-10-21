import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  const adminEmail = process.argv[2] || 'admin@nox.dev';

  const admin = await prisma.user.upsert({
    where: { email: adminEmail },
    update: { role: 'ADMIN' },
    create: {
      email: adminEmail,
      role: 'ADMIN',
      // No password — magic link only
    },
  });

  console.log(`✅ Admin user ready: ${admin.email} (role: ${admin.role})`);
  console.log(`   ID: ${admin.id}`);
}

main()
  .catch(console.error)
  .finally(() => prisma.$disconnect());
