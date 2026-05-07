import { reconcilePendingPayments } from "../src/modules/payments/payments.service";

const limitArg = process.argv[2];
const olderThanArg = process.argv[3];

const parsePositiveInt = (value: string | undefined, fallback: number) => {
  if (!value) return fallback;

  const parsed = Number.parseInt(value, 10);
  return Number.isFinite(parsed) && parsed >= 0 ? parsed : fallback;
};

const main = async () => {
  const summary = await reconcilePendingPayments({
    limit: parsePositiveInt(limitArg, 25),
    olderThanMinutes: parsePositiveInt(olderThanArg, 5),
  });

  console.log(
    JSON.stringify(
      {
        success: true,
        message: "Pending payment reconciliation completed",
        data: summary,
      },
      null,
      2,
    ),
  );
};

main().catch((error) => {
  console.error("Pending payment reconciliation failed", error);
  process.exitCode = 1;
});
