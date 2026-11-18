# Roadmap — E-commerce Starter v1

Status: `[ ]` pendente · `[~]` em andamento · `[x]` concluído e revisado

Cliente demo: **Café Serra Alta** (cafés especiais, Sul de Minas). Dados de demo ficam no seed, nunca no core.

## Fundação

- [x] **01 — Banco:** schema Prisma inicial, migration `init`, `src/lib/db.ts` (singleton)
- [ ] **02 — Seed:** categorias e 15 produtos do Café Serra Alta (variações 250g/500g, grão/moído, kits)
- [ ] **03 — Config e tema:** `store.config.ts` tipado + tokens de tema no Tailwind

## Vitrine

- [ ] **04 — Catálogo:** home, listagem por categoria, página do produto com seleção de variação
- [ ] **05 — Carrinho:** models Cart/CartItem, carrinho anônimo por cookie, adicionar/remover/alterar quantidade
- [ ] **06 — Autenticação:** Auth.js (e-mail e Google), vínculo com Customer, migração do carrinho anônimo

## Checkout

- [ ] **07 — Endereço e frete:** ViaCEP + adapter de frete (fixo e retirada local)
- [ ] **08 — Pagamento:** adapter Mercado Pago (Pix e cartão) + webhook idempotente
  - ⚠️ Atenção: `Order.paymentId @unique` cobre só o vínculo pagamento→pedido. Reenvio de eventos de tipos diferentes (ex.: reembolso) pede uma tabela `PaymentEvent` com `eventId` único.
- [ ] **09 — Pedidos:** transições de status, baixa de estoque em transação, e-mails transacionais (Resend), página "meus pedidos"

## Admin

- [ ] **10 — Produtos:** CRUD com upload de imagens no S3
  - ⚠️ Atenção: variação/produto já vendido não pode ser apagado (`OrderItem.variant` é `Restrict`, produto→variantes é `Cascade`). Usar `active = false` e tratar o erro de FK na UI.
- [ ] **11 — Pedidos e cupons:** listagem, mudança de status, CRUD de cupons, dashboard simples

## Acabamento

- [ ] **12 — Produção:** SEO (metadata, sitemap, OG), banner LGPD, testes do fluxo de checkout, README completo
