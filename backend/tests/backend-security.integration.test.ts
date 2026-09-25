import crypto from "node:crypto";

import { describe, expect, it, vi } from "vitest";

import { env } from "../src/config/env";
import { prisma } from "../src/shared/db/prisma";
import { api, loginAsAccountant, loginAsAdmin } from "./helpers/api-client";

describe("backend security boundaries", () => {
  it("keeps accountant inquiry searches inside the assigned branch", async () => {
    const login = await loginAsAccountant();
    expect(login.status).toBe(200);

    const { orgId, branchId } = login.body.data.user as {
      orgId: string;
      branchId: string | null;
    };
    expect(branchId).toBeTruthy();

    const branch = await prisma.branch.create({
      data: {
        orgId: BigInt(orgId),
        name: `Search boundary ${crypto.randomUUID()}`,
      },
    });
    const subject = `Private finance ${crypto.randomUUID()}`;

    try {
      const created = await api.post("/api/public/inquiries").send({
        inquiryType: "FINANCE",
        fullName: "Other Branch Contact",
        phone: "255700900099",
        subject,
        message: "This finance inquiry belongs to a different branch.",
        sourcePage: "contact",
        branchId: branch.id.toString(),
      });
      expect(created.status).toBe(201);

      const search = await api
        .get(`/api/public-inquiries?search=${encodeURIComponent(subject)}`)
        .set("Authorization", `Bearer ${login.body.data.accessToken as string}`);

      expect(search.status).toBe(200);
      expect(
        (search.body.data as Array<{ id: string }>).some(
          (record) => record.id === created.body.data.id,
        ),
      ).toBe(false);
    } finally {
      await prisma.publicInquiry.deleteMany({ where: { branchId: branch.id } });
      await prisma.branch.delete({ where: { id: branch.id } });
    }
  });

  it("rejects mismatched confirmations and ignores late failed events", async () => {
    expect(env.SNIPPE_WEBHOOK_SECRET).toBeTruthy();

    const org = await prisma.organization.findUniqueOrThrow({
      where: { code: env.PUBLIC_SITE_ORG_CODE },
      select: { id: true },
    });
    const student = await prisma.student.findFirstOrThrow({
      where: { orgId: org.id },
      select: { id: true, branchId: true },
    });
    const id = crypto.randomUUID();
    const reference = `SEC-${id}`;
    const invoice = await prisma.invoice.create({
      data: {
        orgId: org.id,
        branchId: student.branchId,
        studentId: student.id,
        invoiceNo: `SEC-${id}`,
        amountDue: "1000.00",
        amountPaid: "0.00",
        currency: "TZS",
        dueDate: new Date(Date.now() + 24 * 60 * 60 * 1000),
        status: "PENDING",
      },
    });
    const eventIds: string[] = [];
    let paymentId: bigint | null = null;

    const sendWebhook = (
      eventId: string,
      type: string,
      amount: string,
      currency = "TZS",
      signatureOverride?: string,
    ) => {
      const body = JSON.stringify({
        id: eventId,
        type,
        data: {
          reference,
          status: type.split(".")[1],
          amount: { value: amount, currency },
          metadata: { org_id: org.id.toString() },
        },
      });
      const timestamp = Math.floor(Date.now() / 1000).toString();
      const signature = crypto
        .createHmac("sha256", env.SNIPPE_WEBHOOK_SECRET!)
        .update(`${timestamp}.${body}`)
        .digest("hex");

      return api
        .post("/api/webhooks/snippe")
        .set("Content-Type", "application/json")
        .set("X-Webhook-Timestamp", timestamp)
        .set("X-Webhook-Signature", signatureOverride ?? signature)
        .send(body);
    };

    try {
      const payment = await prisma.payment.create({
        data: {
          orgId: org.id,
          invoiceId: invoice.id,
          provider: "SNIPPE",
          reference,
          amount: "1000.00",
          currency: "TZS",
          status: "PENDING",
        },
      });
      paymentId = payment.id;

      const wrongAmountId = `wrong-amount-${id}`;
      eventIds.push(wrongAmountId);
      expect((await sendWebhook(wrongAmountId, "payment.completed", "2000.00")).status).toBe(409);

      const wrongCurrencyId = `wrong-currency-${id}`;
      eventIds.push(wrongCurrencyId);
      expect((await sendWebhook(wrongCurrencyId, "payment.completed", "1000.00", "USD")).status).toBe(409);

      expect((await prisma.payment.findUniqueOrThrow({ where: { id: payment.id } })).status).toBe("PENDING");

      const completedId = `completed-${id}`;
      eventIds.push(completedId);
      expect((await sendWebhook(completedId, "payment.completed", "1000.00")).status).toBe(200);

      const lateFailureId = `late-failure-${id}`;
      eventIds.push(lateFailureId);
      expect((await sendWebhook(lateFailureId, "payment.failed", "1000.00")).status).toBe(200);
      expect((await sendWebhook(completedId, "payment.completed", "1000.00", "TZS", "bad-signature")).status).toBe(401);

      const finalPayment = await prisma.payment.findUniqueOrThrow({ where: { id: payment.id } });
      const finalInvoice = await prisma.invoice.findUniqueOrThrow({ where: { id: invoice.id } });
      expect(finalPayment.status).toBe("COMPLETED");
      expect(finalInvoice.status).toBe("PAID");
      expect(finalInvoice.amountPaid.toFixed(2)).toBe("1000.00");
    } finally {
      await prisma.paymentWebhook.deleteMany({ where: { eventId: { in: eventIds } } });
      if (paymentId) await prisma.payment.delete({ where: { id: paymentId } });
      await prisma.invoice.delete({ where: { id: invoice.id } });
    }
  });
  it("settles immediate confirmations and keeps uncertain requests pending", async () => {
    const login = await loginAsAdmin();
    expect(login.status).toBe(200);

    const org = await prisma.organization.findUniqueOrThrow({
      where: { code: env.PUBLIC_SITE_ORG_CODE },
      select: { id: true },
    });
    const student = await prisma.student.findFirstOrThrow({
      where: { orgId: org.id },
      select: { id: true, branchId: true },
    });
    const id = crypto.randomUUID();
    const invoiceIds: bigint[] = [];
    const originalMockMode = env.SNIPPE_MOCK_MODE;
    const originalApiKey = env.SNIPPE_API_KEY;
    const fetchSpy = vi.spyOn(globalThis, "fetch");

    const createInvoice = async (prefix: string) => {
      const invoice = await prisma.invoice.create({
        data: {
          orgId: org.id,
          branchId: student.branchId,
          studentId: student.id,
          invoiceNo: `${prefix}-${id}`,
          amountDue: "1000.00",
          amountPaid: "0.00",
          currency: "TZS",
          dueDate: new Date(Date.now() + 24 * 60 * 60 * 1000),
          status: "PENDING",
        },
      });
      invoiceIds.push(invoice.id);
      return invoice;
    };

    const initiate = (invoiceId: bigint) =>
      api
        .post("/api/payments")
        .set("Authorization", `Bearer ${login.body.data.accessToken as string}`)
        .send({
          invoiceId: invoiceId.toString(),
          payerPhone: "255700900099",
          channel: "mpesa",
          customer: { firstname: "Payment", lastname: "Test" },
        });

    try {
      env.SNIPPE_MOCK_MODE = false;
      env.SNIPPE_API_KEY = "integration-test-key";

      const completedInvoice = await createInvoice("IMM");
      fetchSpy.mockResolvedValueOnce(
        new Response(
          JSON.stringify({
            status: "success",
            data: {
              reference: `IMM-${id}`,
              status: "completed",
              completed_at: new Date().toISOString(),
              amount: { value: 1000, currency: "TZS" },
            },
          }),
          { status: 201, headers: { "Content-Type": "application/json" } },
        ),
      );

      expect((await initiate(completedInvoice.id)).status).toBe(201);
      const completedPayment = await prisma.payment.findFirstOrThrow({
        where: { invoiceId: completedInvoice.id },
      });
      const paidInvoice = await prisma.invoice.findUniqueOrThrow({
        where: { id: completedInvoice.id },
      });
      expect(completedPayment.status).toBe("COMPLETED");
      expect(paidInvoice.status).toBe("PAID");
      expect(paidInvoice.amountPaid.toFixed(2)).toBe("1000.00");

      const uncertainInvoice = await createInvoice("UNC");
      fetchSpy.mockRejectedValueOnce(new Error("provider connection lost"));
      expect((await initiate(uncertainInvoice.id)).status).toBe(502);
      const uncertainPayment = await prisma.payment.findFirstOrThrow({
        where: { invoiceId: uncertainInvoice.id },
      });
      expect(uncertainPayment.status).toBe("PENDING");
    } finally {
      fetchSpy.mockRestore();
      env.SNIPPE_MOCK_MODE = originalMockMode;
      env.SNIPPE_API_KEY = originalApiKey;
      await prisma.payment.deleteMany({ where: { invoiceId: { in: invoiceIds } } });
      await prisma.invoice.deleteMany({ where: { id: { in: invoiceIds } } });
    }
  });
});
