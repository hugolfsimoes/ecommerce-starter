@AGENTS.md

# E-commerce Starter

Starter reutilizável para lojas virtuais de clientes freelance.
**Regra de ouro:** o core é genérico e não conhece nenhum cliente. Tudo que é específico de cliente entra por `store.config.ts`, adapters ou `src/custom/`.

## Stack

- Next.js (App Router) + TypeScript (strict)
- PostgreSQL + Prisma
- Tailwind CSS
- Pagamento: Mercado Pago (via adapter)
- Imagens: AWS S3

## Comandos

- `docker compose up -d` — sobe o Postgres (porta **5433** no host)
- `npm run dev` — servidor local em http://localhost:3000
- `npm run lint` — ESLint
- `npx tsc --noEmit` — checagem de tipos
- `npx prisma migrate dev --name <nome>` — cria e aplica migration
- `npx prisma studio` — inspeciona o banco

## Estrutura

- `src/app/` — rotas (vitrine em `(store)`, painel em `admin/`)
- `src/lib/db.ts` — Prisma client (singleton, único ponto de acesso ao banco)
- `src/lib/adapters/<tipo>/` — integrações externas (payment, shipping, email). Cada tipo tem `types.ts` com a interface; cada provedor implementa essa interface
- `src/modules/<domínio>/` — regras de negócio (catalog, cart, checkout, orders)
- `src/custom/` — código específico do cliente (vazio no starter)
- `store.config.ts` — nome, tema, provedores ativos e feature flags

## Regras do domínio (não negociáveis)

- **Dinheiro sempre em centavos (`Int`)**, campos com sufixo `Cents`. Nunca `Float`. Formatar só na UI com `Intl.NumberFormat("pt-BR", { style: "currency", currency: "BRL" })`.
- `OrderItem` guarda snapshot (nome, variação, preço unitário). Nunca recalcular pedido antigo a partir do produto atual.
- Webhooks de pagamento são **idempotentes**: usar `paymentId` único e tratar reenvio sem duplicar efeito.
- Baixa de estoque e mudança de status do pedido acontecem na mesma transação (`prisma.$transaction`).
- Status do pedido só muda por transições válidas: PENDING → PAID → SHIPPED → DELIVERED; PENDING/PAID → CANCELED; PAID → REFUNDED.
- Preço e total são sempre calculados no servidor. Nunca confiar em valor vindo do cliente.

## Padrões de código

- Server Components por padrão; `"use client"` só quando houver interação/estado no browser.
- Mutations via Server Actions ou route handlers, com input validado por **Zod**.
- Lógica de negócio fica em `src/modules/`, não dentro de componentes ou rotas.
- Integração externa nova = novo adapter implementando a interface existente. Nunca chamar SDK de terceiro direto fora de `src/lib/adapters/`.
- Sem `any`. Tipos de domínio derivados do Prisma ou de schemas Zod.
- Código, nomes e commits em inglês; textos exibidos ao usuário em português (pt-BR).
- Nunca editar migration já aplicada: criar uma nova.
- Nunca commitar `.env`. Variável nova vai também para `.env.example`.

## Commits

Conventional Commits: `feat:`, `fix:`, `chore:`, `refactor:`, `test:`, `docs:`.

## Fluxo de trabalho (um step por vez)

- O plano macro está em `docs/ROADMAP.md`. Trabalhe em **um único step por vez** e nunca adiante o próximo.
- Para cada step: escreva o plano detalhado com o superpowers (write-plan), salve em `docs/plans/` e **aguarde minha aprovação** antes de executar.
- Execute em lotes pequenos e pare para eu revisar entre os lotes.
- Use brainstorm só quando o step tiver decisão de design em aberto.
- TDD é obrigatório para regras de negócio (`src/modules/`, adapters, webhooks). Em setup, config e telas sem lógica, testes são opcionais.
- Ao concluir o step: rode `npm run lint` e `npx tsc --noEmit`, rode o agent `code-reviewer`, marque o step como `[~]` no ROADMAP e me entregue um resumo e uma sugestão de mensagem de commit.
- **Não faça commits.** Eu reviso o diff, faço o commit e marco o step como `[x]`.
- Não adicionar dependência nova sem justificar no plano.
