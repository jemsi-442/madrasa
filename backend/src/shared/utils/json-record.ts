// Prisma IDs are bigint; Decimal and Date retain their own JSON representations.
export const jsonRecord = (value: unknown): unknown =>
  JSON.parse(JSON.stringify(value, (_key, item: unknown) =>
    typeof item === "bigint" ? item.toString() : item));
