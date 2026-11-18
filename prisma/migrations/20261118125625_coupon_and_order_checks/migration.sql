-- CHECK constraints (not representable in schema.prisma; see "Constraints no banco" in CLAUDE.md)

ALTER TABLE "Coupon"
  ADD CONSTRAINT "Coupon_maxUses_check" CHECK ("maxUses" IS NULL OR "maxUses" > 0),
  ADD CONSTRAINT "Coupon_usedCount_check" CHECK ("usedCount" >= 0),
  ADD CONSTRAINT "Coupon_usedCount_maxUses_check" CHECK ("maxUses" IS NULL OR "usedCount" <= "maxUses");

ALTER TABLE "Order"
  ADD CONSTRAINT "Order_total_consistency_check" CHECK ("totalCents" = "subtotalCents" + "shippingCents" - "discountCents");
