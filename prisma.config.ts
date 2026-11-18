import "dotenv/config";
import { defineConfig } from "prisma/config";

export default defineConfig({
  schema: "prisma/schema.prisma",
  migrations: {
    path: "prisma/migrations",
  },
  datasource: {
    // Not env(): it throws when the variable is missing, which would break
    // `prisma generate` (postinstall) on a fresh clone or CI without a .env.
    // generate never connects; migrate/studio fail on the empty URL.
    url: process.env.DATABASE_URL ?? "",
  },
});
