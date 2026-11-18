# Step 01 — Banco: Plano de Implementação

> **Para quem executa:** use superpowers:executing-plans. Execução em lotes (um lote = uma Task), parando para revisão do Hugo entre lotes. **Não fazer commits** (regra do CLAUDE.md). Passos usam checkbox (`- [ ]`).

**Objetivo:** schema Prisma inicial aplicado no Postgres local via migration `init`, com client singleton em `src/lib/db.ts`.

**Arquitetura:** Prisma ORM 7.10.1 (última estável) com o generator `prisma-client` gerando o client em `src/generated/prisma` (fora do git), conexão via driver adapter `@prisma/adapter-pg` e URL do banco lida em `prisma.config.ts`. `db.ts` guarda a instância em `globalThis` em dev para sobreviver ao hot reload.

**Stack:** Next.js 16.4.6, TypeScript strict, PostgreSQL 16 (docker, porta 5433), Prisma 7.10.1.

**Spec:** pedido do Step 01 na conversa + `CLAUDE.md` + `docs/ROADMAP.md` (item 01).

## Restrições globais

- Versões **fixas** (sem `^`) para `prisma` e `@prisma/client`; aplico o mesmo às outras deps novas deste step.
- Models exatamente como enviados. As sugestões da seção "Revisão do schema" só entram se aprovadas.
- Dinheiro em centavos (`Int`, sufixo `Cents`), nunca `Float`.
- Nunca editar migration já aplicada. (A `init` ainda não existe, então ajustar o SQL dela **antes** de aplicar é permitido; só é necessário se S1 for aprovada.)
- Variável nova também vai para `.env.example` (este step não cria nenhuma).
- Fora do escopo: seed, telas, auth, testes.

## Revisão do Prisma (fatos que guiam o plano)

Verificados no pacote `prisma@7.10.1` e na doc do Next instalada:

1. **`latest` no npm aponta para `8.0.0-rc.34`.** Por isso `npm i prisma` trouxe o RC. A última estável é **7.10.1**, a mesma versão de `@prisma/client` e `@prisma/adapter-pg`.
2. **Formato da 7.x** (templates do `prisma init` 7.10.1):
   - `generator client { provider = "prisma-client"; output = "../src/generated/prisma" }`
   - `datasource db { provider = "postgresql" }`, **sem `url`**. A URL vai para `prisma.config.ts` (`defineConfig` + `env("DATABASE_URL")` de `prisma/config`).
   - O CLI **não carrega `.env` sozinho**: o template coloca `import "dotenv/config"` no `prisma.config.ts`.
   - Na 7.x o `PrismaClient` exige driver adapter. Para Postgres, `@prisma/adapter-pg`.
3. **O Next 16 já trata `@prisma/client` e `pg` como pacotes externos** (`serverExternalPackages.md`). O `next.config.ts` não muda.

## Dependências (justificativa)

| Pacote | Onde | Versão | Por quê |
|---|---|---|---|
| `prisma` | dev | `7.10.1` | Substitui o RC; CLI na mesma versão do client. |
| `@prisma/client` | prod | `7.10.1` | Já instalado; só fixar a versão. |
| `@prisma/adapter-pg` | prod | `7.10.1` | Obrigatório na 7.x para conectar no Postgres. |
| `dotenv` | dev | `17.4.2` | Só o CLI usa, para ler `.env` no `prisma.config.ts`. A 17.4.2 já está na árvore como dependência transitiva; evito a major 18, recém-lançada. |
| ~~`pg`~~ | — | — | **Não adiciono.** O `PrismaPg` recebe `{ connectionString }`, o `db.ts` não importa `pg`, e `pg` + `@types/pg` já vêm como dependências do adapter. |

## Revisão do schema (sugestões — **não aplicadas sem aprovação**)

O schema já atende às regras centrais: dinheiro em `Int` `*Cents`, snapshot no `OrderItem` (`productName`, `variantName`, `sku`, `unitPriceCents`), `paymentId @unique` (nullable no Postgres permite vários `NULL`), enum com os 6 status e FKs com índice.

Sugestões, em ordem de importância:

- **S1 — CHECK constraints no banco** (edição do SQL da `init` com `--create-only`, antes de aplicar):
  `ProductVariant.stock >= 0`, `priceCents >= 0`; `OrderItem.quantity > 0`, `unitPriceCents >= 0`; `Order` com todos os `*Cents >= 0`; `Coupon.percentOff BETWEEN 1 AND 100`; `Coupon` com **exatamente um** entre `percentOff` e `amountOffCents`.
  *Por quê:* `stock >= 0` é a garantia final contra vender mais do que há em estoque quando dois checkouts concorrentes dão baixa ao mesmo tempo (Step 09): o `UPDATE` falha e a transação reverte. As outras protegem invariantes que o Prisma não expressa. Custo: ficam só no SQL, invisíveis no `schema.prisma`; deixo um comentário no schema apontando para elas.
- **S2 — `Order.number Int @unique @default(autoincrement())`.**
  *Por quê:* o cliente final precisa de um número legível ("Pedido #1042") em e-mails e no suporte; um cuid não serve para isso. Adicionar agora evita migration com backfill depois.
- **S3 — `@@index([customerEmail])` em `Order`.**
  *Por quê:* o Step 06 vincula pedidos feitos sem login ao `Customer` pelo e-mail, e "meus pedidos" consulta por ele.
- **S4 — Em `ProductImage`, trocar `@@index([productId])` por `@@index([productId, position])`.**
  *Por quê:* a imagem é sempre buscada por produto e ordenada por posição. O índice composto também atende às buscas só por `productId`.
- **S5 — Em `Product`, trocar `@@index([active])` por `@@index([categoryId, active])` e remover `@@index([categoryId])`.**
  *Por quê:* um índice sozinho num booleano quase nunca é usado pelo planner; a consulta real da vitrine é "ativos da categoria X".

Pontos que **não** pedem mudança, só registro:

- `OrderItem.variant` com `onDelete: Restrict`: correto com o snapshot. Consequência: variação ou produto que já foi vendido não pode ser apagado, só desativado (`active = false`). O Step 10 precisa seguir isso.
- `Order.couponCode` como string, sem FK: é um snapshot, coerente com a regra do `OrderItem`.
- `Customer.email` e `Coupon.code` são `@unique` mas sensíveis a maiúsculas e minúsculas: normalizar no código (e-mail em minúsculas, cupom em maiúsculas) nos Steps 06 e 11.
- Idempotência de webhook: `paymentId @unique` cobre o vínculo pagamento→pedido. Se houver tabela de eventos, ela fica para o Step 08.

## Arquivos

- Criar: `prisma/schema.prisma`, `prisma.config.ts`, `src/lib/db.ts`, `prisma/migrations/<timestamp>_init/migration.sql` (gerado)
- Modificar: `package.json`, `package-lock.json`, `.gitignore`, `eslint.config.mjs`, `docs/ROADMAP.md`

## Pontos de atenção na revisão

1. **Hot reload:** salvar um arquivo em dev não pode criar um novo `PrismaClient` (pool de conexões) a cada reload.
2. **`DATABASE_URL` ausente:** o `db.ts` deve falhar com uma mensagem clara, não com um erro obscuro do driver.
3. **Clone novo:** o client gerado fica fora do git, então `npm install` precisa gerá-lo (`postinstall`), senão `tsc` e `dev` quebram.
4. **CLI sem `.env`:** `prisma migrate` e `prisma studio` precisam enxergar a `DATABASE_URL` (o `dotenv/config` no config resolve).
5. **Lint e tsc sobre código gerado:** o ESLint não pode varrer `src/generated/`.

---

### Task 1 (Lote 1): Dependências, config e schema

**Files:** Create `prisma/schema.prisma`, `prisma.config.ts` · Modify `package.json`, `package-lock.json`, `.gitignore`, `eslint.config.mjs`

**Produz:** client gerado em `src/generated/prisma`, importável como `@/generated/prisma/client` (exporta `PrismaClient`, `Prisma`, `OrderStatus`).

- [ ] **1.1** Trocar as versões:
  `npm install -E @prisma/client@7.10.1 @prisma/adapter-pg@7.10.1`
  `npm install -D -E prisma@7.10.1 dotenv@17.4.2`
  Esperado: `package.json` sem `^` nesses quatro; `npx prisma --version` mostra `7.10.1`.
- [ ] **1.2** Criar `prisma.config.ts`: `import "dotenv/config"`; `defineConfig({ schema: "prisma/schema.prisma", migrations: { path: "prisma/migrations" }, datasource: { url: env("DATABASE_URL") } })`.
- [ ] **1.3** Criar `prisma/schema.prisma` com o generator e o datasource da seção "Revisão do Prisma" e, abaixo, os models **exatamente** como enviados (mais as sugestões aprovadas).
- [ ] **1.4** Em `.gitignore`, adicionar `/src/generated/`. Em `eslint.config.mjs`, adicionar `"src/generated/**"` ao `globalIgnores`.
- [ ] **1.5** `npx prisma validate` deve passar; `npx prisma generate` deve criar `src/generated/prisma/client.ts`.

**⏸ Parar para revisão.**

### Task 2 (Lote 2): Migration `init` e scripts

**Files:** Create `prisma/migrations/<ts>_init/` · Modify `package.json`

- [ ] **2.1** Scripts no `package.json`:
  - `"db:migrate": "prisma migrate dev && prisma generate"` (na 7.x o `migrate dev` não roda mais o `generate`)
  - `"db:studio": "prisma studio"`
  - `"db:reset": "prisma migrate reset"`
  - `"postinstall": "prisma generate"` (ponto de atenção 3)
- [ ] **2.2** Gerar a migration:
  - **Com S1:** `npx prisma migrate dev --name init --create-only`, acrescentar os `ALTER TABLE ... ADD CONSTRAINT ... CHECK (...)` ao final do `migration.sql`, depois `npm run db:migrate`.
  - **Sem S1:** `npm run db:migrate -- --name init`.
- [ ] **2.3** Confirmar no banco: `docker compose exec -T db psql -U postgres -d ecommerce -c '\dt'`. Esperado: `Category`, `Coupon`, `Customer`, `Order`, `OrderItem`, `Product`, `ProductImage`, `ProductVariant`, `_prisma_migrations`. E `-c '\dT'` lista `OrderStatus`. Com S1, `-c '\d "ProductVariant"'` mostra as constraints CHECK.
- [ ] **2.4** `npx prisma migrate status` deve responder "Database schema is up to date".

**⏸ Parar para revisão.**

### Task 3 (Lote 3): `src/lib/db.ts` e fechamento

**Files:** Create `src/lib/db.ts` · Modify `docs/ROADMAP.md`

**Produz:** `export const prisma: PrismaClient`, o único ponto de acesso ao banco, usado por `src/modules/*` a partir do Step 02.

- [ ] **3.1** Criar `src/lib/db.ts`:
  - `createPrismaClient(): PrismaClient` lê `process.env.DATABASE_URL`. Se faltar, lança `Error("DATABASE_URL is not set")`. Se existir, cria `new PrismaClient({ adapter: new PrismaPg({ connectionString }), log })`, com `log` igual a `["warn", "error"]` em dev e `["error"]` em produção.
  - Singleton: `const globalForPrisma = globalThis as unknown as { prisma?: PrismaClient }`; `prisma = globalForPrisma.prisma ?? createPrismaClient()`; fora de produção, guardar em `globalForPrisma.prisma`.
  - Sem `any`; import de `@/generated/prisma/client`.
- [ ] **3.2** Teste rápido de conexão (descartável, fora do repo): `npx tsx -e 'import { prisma } from "./src/lib/db"; prisma.category.count().then(n => { console.log(n); return prisma.$disconnect(); })'`. Esperado: `0`. *(`tsx` via npx, sem adicionar dependência; se o alias `@/` não resolver, pular e confiar no tsc + migration.)*
- [ ] **3.3** `npm run lint` e `npx tsc --noEmit` sem erros.
- [ ] **3.4** Rodar o agent `code-reviewer` sobre o diff e tratar os apontamentos.
- [ ] **3.5** Marcar `[~]` no item 01 do `docs/ROADMAP.md`.
- [ ] **3.6** Entregar o resumo e a mensagem de commit sugerida, por exemplo `feat: add initial Prisma schema, init migration and db client`.

---

## Decisões que preciso de você

1. Quais sugestões aprovar: **S1, S2, S3, S4, S5** (todas, nenhuma ou algumas).
2. Ok com `postinstall: prisma generate` e com o `dotenv` 17.4.2 como devDependency?
