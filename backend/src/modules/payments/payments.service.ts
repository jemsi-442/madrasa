import crypto from "node:crypto";

import { Prisma } from "@prisma/client";

import { env } from "../../config/env";
import { prisma } from "../../shared/db/prisma";
import { HttpError } from "../../shared/errors/http-error";
import type { InitiatePaymentInput, ListPaymentsQuery } from "./payments.schemas";
import {
  createSnippePayment,
  getSnippePaymentStatus,
  type SnippePaymentRecord,
  type SnippeProviderError,
} from "./snippe.client";

type SnippeWebhookPayload = {
  id?: string;
  type?: string;
  api_version?: string;
  created_at?: string;
  data?: {
    reference?: string;
    external_reference?: string;
    status?: string;
    completed_at?: string;
    amount?: {
      value?: number | string;
      currency?: string;
    };
    metadata?: {
      invoice_id?: number | string;
      org_id?: number | string;
    };
  };
};

type PaymentRecordWithInvoice = Prisma.PaymentGetPayload<{
  include: {
    invoice: {
      select: {
        id: true;
        invoiceNo: true;
        branchId: true;
        student: {
          select: {
            id: true;
            fullName: true;
            admissionNo: true;
          };
        };
      };
    };
  };
}>;

type PaymentReceiptRecord = Prisma.PaymentGetPayload<{
  include: {
    organization: {
      select: {
        id: true;
        name: true;
        code: true;
      };
    };
    invoice: {
      select: {
        id: true;
        invoiceNo: true;
        amountDue: true;
        amountPaid: true;
        dueDate: true;
        status: true;
        branch: {
          select: {
            id: true;
            name: true;
          };
        };
        student: {
          select: {
            id: true;
            fullName: true;
            admissionNo: true;
          };
        };
      };
    };
  };
}>;

type PaymentStateUpdateInput = {
  paymentId: bigint;
  source: "webhook" | "reconcile";
  sourceLabel: string;
  eventType?: string | null;
  actorUserId?: bigint | null;
  ipAddress?: string | null;
  rawResponse: Prisma.InputJsonValue;
  status?: string | null;
  externalReference?: string | null;
  completedAt?: string | null;
  expiresAt?: string | null;
  apiVersion?: string | null;
  amountValue?: number | string | null;
  metadata?: Prisma.InputJsonValue;
};

const SNIPPE_API_VERSION = "2026-01-25";
const WEBHOOK_TOLERANCE_SECONDS = 300;

const toMoneyString = (value: Prisma.Decimal | string | number) => new Prisma.Decimal(value).toFixed(2);
const toDateString = (value: Date) => value.toISOString().slice(0, 10);

const buildWebhookUrl = () => new URL("/api/webhooks/snippe", env.APP_BASE_URL).toString();

const toPaymentResponse = (record: PaymentRecordWithInvoice) => ({
  id: record.id.toString(),
  orgId: record.orgId.toString(),
  invoiceId: record.invoiceId.toString(),
  provider: record.provider,
  reference: record.reference,
  externalReference: record.externalReference,
  providerTxnRef: record.providerTxnRef,
  requestId: record.requestId,
  amount: toMoneyString(record.amount),
  currency: record.currency,
  status: record.status,
  paymentType: record.paymentType,
  channel: record.channel,
  apiVersion: record.apiVersion,
  expiresAt: record.expiresAt?.toISOString() ?? null,
  paidAt: record.paidAt?.toISOString() ?? null,
  createdAt: record.createdAt.toISOString(),
  invoice: {
    id: record.invoice.id.toString(),
    invoiceNo: record.invoice.invoiceNo,
    branchId: record.invoice.branchId.toString(),
    student: record.invoice.student
      ? {
          id: record.invoice.student.id.toString(),
          fullName: record.invoice.student.fullName,
          admissionNo: record.invoice.student.admissionNo,
        }
      : null,
  },
});

const buildReceiptNo = (paymentId: bigint, paidAt: Date | null, createdAt: Date) => {
  const basisDate = paidAt ?? createdAt;
  const stamp = `${basisDate.getUTCFullYear()}${String(basisDate.getUTCMonth() + 1).padStart(2, "0")}${String(
    basisDate.getUTCDate(),
  ).padStart(2, "0")}`;
  const serial = paymentId.toString().padStart(6, "0");

  return `RCP-${stamp}-${serial}`;
};

const toPaymentReceiptResponse = (record: PaymentReceiptRecord) => ({
  receiptNo: buildReceiptNo(record.id, record.paidAt, record.createdAt),
  payment: {
    id: record.id.toString(),
    orgId: record.orgId.toString(),
    invoiceId: record.invoiceId.toString(),
    amount: toMoneyString(record.amount),
    currency: record.currency,
    status: record.status,
    channel: record.channel,
    reference: record.reference,
    externalReference: record.externalReference,
    providerTxnRef: record.providerTxnRef,
    paidAt: record.paidAt?.toISOString() ?? null,
    createdAt: record.createdAt.toISOString(),
  },
  organization: {
    id: record.organization.id.toString(),
    name: record.organization.name,
    code: record.organization.code,
  },
  branch: record.invoice.branch
    ? {
        id: record.invoice.branch.id.toString(),
        name: record.invoice.branch.name,
      }
    : null,
  student: {
    id: record.invoice.student.id.toString(),
    fullName: record.invoice.student.fullName,
    admissionNo: record.invoice.student.admissionNo,
  },
  invoice: {
    id: record.invoice.id.toString(),
    invoiceNo: record.invoice.invoiceNo,
    amountDue: toMoneyString(record.invoice.amountDue),
    amountPaid: toMoneyString(record.invoice.amountPaid),
    balanceRemaining: toMoneyString(record.invoice.amountDue.minus(record.invoice.amountPaid)),
    dueDate: toDateString(record.invoice.dueDate),
    status: record.invoice.status,
  },
});

const createAuditLog = async (input: {
  orgId: bigint;
  actorUserId?: bigint | null;
  action: string;
  entityType: string;
  entityId: string;
  metadata?: Prisma.InputJsonValue;
  ipAddress?: string | null;
}) => {
  const data: Prisma.AuditLogUncheckedCreateInput = {
    orgId: input.orgId,
    actorUserId: input.actorUserId ?? null,
    action: input.action,
    entityType: input.entityType,
    entityId: input.entityId,
    ipAddress: input.ipAddress ?? null,
  };

  if (input.metadata !== undefined) {
    data.metadata = input.metadata;
  }

  await prisma.auditLog.create({ data });
};

const mapSnippeStatus = (status?: string, eventType?: string) => {
  if (eventType === "payment.completed") return "COMPLETED" as const;
  if (eventType === "payment.failed") return "FAILED" as const;
  if (eventType === "payment.voided") return "VOIDED" as const;
  if (eventType === "payment.expired") return "EXPIRED" as const;

  switch ((status ?? "").toLowerCase()) {
    case "completed":
      return "COMPLETED" as const;
    case "failed":
      return "FAILED" as const;
    case "voided":
      return "VOIDED" as const;
    case "expired":
      return "EXPIRED" as const;
    default:
      return "PENDING" as const;
  }
};

const mapSnippeErrorToHttpError = (error: SnippeProviderError) => {
  if (error.httpStatus === 400) {
    return new HttpError(422, error.providerMessage, {
      provider: "SNIPPE",
      providerCode: error.providerCode,
      retryable: error.retryable,
      responseBody: error.responseBody,
    });
  }

  if (error.httpStatus === 401 || error.httpStatus === 403) {
    return new HttpError(503, "Snippe authentication failed", {
      provider: "SNIPPE",
      providerCode: error.providerCode,
      retryable: error.retryable,
      responseBody: error.responseBody,
    });
  }

  if (error.httpStatus === 429) {
    return new HttpError(503, "Snippe rate limit reached, try again shortly", {
      provider: "SNIPPE",
      providerCode: error.providerCode,
      retryable: error.retryable,
      responseBody: error.responseBody,
    });
  }

  if (error.httpStatus >= 500) {
    return new HttpError(502, error.providerMessage, {
      provider: "SNIPPE",
      providerCode: error.providerCode,
      retryable: error.retryable,
      responseBody: error.responseBody,
    });
  }

  return new HttpError(502, error.providerMessage, {
    provider: "SNIPPE",
    providerCode: error.providerCode,
    retryable: error.retryable,
    responseBody: error.responseBody,
  });
};

const buildSnippeWebhookSignature = (timestamp: string, rawBody: string) => {
  const secret = env.SNIPPE_WEBHOOK_SECRET;

  if (!secret) {
    throw new HttpError(500, "SNIPPE_WEBHOOK_SECRET is not configured");
  }

  return crypto.createHmac("sha256", secret).update(`${timestamp}.${rawBody}`).digest("hex");
};

const verifySnippeWebhookSignature = (timestamp: string, signature: string, rawBody: string) => {
  const nowSeconds = Math.floor(Date.now() / 1000);
  const parsedTimestamp = Number(timestamp);

  if (!Number.isFinite(parsedTimestamp)) {
    throw new HttpError(400, "Invalid webhook timestamp");
  }

  if (Math.abs(nowSeconds - parsedTimestamp) > WEBHOOK_TOLERANCE_SECONDS) {
    throw new HttpError(400, "Webhook timestamp is stale");
  }

  const expected = buildSnippeWebhookSignature(timestamp, rawBody);
  const expectedBuffer = Buffer.from(expected, "utf8");
  const receivedBuffer = Buffer.from(signature, "utf8");

  if (expectedBuffer.length !== receivedBuffer.length) {
    throw new HttpError(401, "Invalid webhook signature");
  }

  if (!crypto.timingSafeEqual(expectedBuffer, receivedBuffer)) {
    throw new HttpError(401, "Invalid webhook signature");
  }
};

const recalculateInvoiceAmounts = async (tx: Prisma.TransactionClient, invoiceId: bigint) => {
  const invoice = await tx.invoice.findUniqueOrThrow({
    where: { id: invoiceId },
    select: {
      amountDue: true,
      dueDate: true,
    },
  });

  const totals = await tx.payment.aggregate({
    where: {
      invoiceId,
      status: "COMPLETED",
    },
    _sum: {
      amount: true,
    },
  });

  const amountPaid = totals._sum.amount ?? new Prisma.Decimal(0);
  let status: "PENDING" | "PARTIALLY_PAID" | "PAID" | "OVERDUE" = "PENDING";
  const today = new Date();

  if (amountPaid.greaterThanOrEqualTo(invoice.amountDue)) {
    status = "PAID";
  } else if (amountPaid.greaterThan(0)) {
    status = "PARTIALLY_PAID";
  } else if (invoice.dueDate < today) {
    status = "OVERDUE";
  }

  await tx.invoice.update({
    where: { id: invoiceId },
    data: { amountPaid, status },
  });
};

const getPaymentWithInvoice = async (paymentId: bigint, tx: Prisma.TransactionClient | typeof prisma = prisma) =>
  tx.payment.findUniqueOrThrow({
    where: { id: paymentId },
    include: {
      invoice: {
        select: {
          id: true,
          invoiceNo: true,
          branchId: true,
          student: {
            select: {
              id: true,
              fullName: true,
              admissionNo: true,
            },
          },
        },
      },
    },
  });

const applyPaymentStateUpdate = async (input: PaymentStateUpdateInput) => {
  await prisma.$transaction(async (tx) => {
    const current = await tx.payment.findUniqueOrThrow({
      where: { id: input.paymentId },
      select: {
        id: true,
        orgId: true,
        invoiceId: true,
        amount: true,
        status: true,
        externalReference: true,
        providerTxnRef: true,
        paidAt: true,
        expiresAt: true,
        apiVersion: true,
      },
    });

    const nextStatus = mapSnippeStatus(input.status ?? undefined, input.eventType ?? undefined);
    const amount = input.amountValue !== undefined && input.amountValue !== null
      ? new Prisma.Decimal(input.amountValue.toString())
      : current.amount;
    const paidAt = input.completedAt ? new Date(input.completedAt) : current.paidAt;
    const expiresAt = input.expiresAt ? new Date(input.expiresAt) : current.expiresAt;

    await tx.payment.update({
      where: { id: current.id },
      data: {
        status: nextStatus,
        amount,
        paidAt,
        expiresAt,
        apiVersion: input.apiVersion ?? current.apiVersion,
        externalReference: input.externalReference ?? current.externalReference,
        providerTxnRef: input.externalReference ?? current.providerTxnRef,
        rawResponse: input.rawResponse,
      },
    });

    await recalculateInvoiceAmounts(tx, current.invoiceId);

    await tx.auditLog.create({
      data: {
        orgId: current.orgId,
        actorUserId: input.actorUserId ?? null,
        action: `payment.${input.source}_processed`,
        entityType: "payment",
        entityId: current.id.toString(),
        ipAddress: input.ipAddress ?? null,
        metadata: {
          source: input.sourceLabel,
          statusBefore: current.status,
          statusAfter: nextStatus,
          eventType: input.eventType ?? null,
          ...(input.metadata && typeof input.metadata === "object" ? input.metadata : {}),
        } as Prisma.InputJsonValue,
      },
    });
  });

  return getPaymentWithInvoice(input.paymentId);
};

const buildInitiationAuditMetadata = (
  input: InitiatePaymentInput,
  requestId: string,
  paymentId: bigint,
  providerReference?: string | null,
) => ({
  invoiceId: input.invoiceId,
  requestId,
  paymentId: paymentId.toString(),
  reference: providerReference ?? null,
  mockMode: env.SNIPPE_MOCK_MODE,
});

const buildProviderPayloadFromSnippe = (record: SnippePaymentRecord) => ({
  reference: record.reference ?? null,
  external_reference: record.external_reference ?? null,
  status: record.status ?? null,
  completed_at: record.completed_at ?? null,
  expires_at: record.expires_at ?? null,
  api_version: record.api_version ?? null,
  amount: record.amount ?? null,
  channel: record.channel ?? null,
  payment_type: record.payment_type ?? null,
  customer: record.customer ?? null,
  metadata: record.metadata ?? null,
});

export const initiatePayment = async (
  orgId: string,
  actorUserId: string,
  input: InitiatePaymentInput,
  ipAddress?: string,
) => {
  const parsedOrgId = BigInt(orgId);
  const parsedActorUserId = BigInt(actorUserId);
  const parsedInvoiceId = BigInt(input.invoiceId);

  const invoice = await prisma.invoice.findFirst({
    where: {
      id: parsedInvoiceId,
      orgId: parsedOrgId,
    },
    include: {
      student: {
        select: {
          id: true,
          fullName: true,
          admissionNo: true,
        },
      },
    },
  });

  if (!invoice) {
    throw new HttpError(404, "Invoice not found for this organization");
  }

  if (invoice.status === "PAID" || invoice.status === "CANCELLED") {
    throw new HttpError(409, "This invoice cannot accept a new payment request");
  }

  const outstandingAmount = invoice.amountDue.minus(invoice.amountPaid);

  if (outstandingAmount.lessThanOrEqualTo(0)) {
    throw new HttpError(409, "Invoice balance is already settled");
  }

  const requestId = crypto.randomUUID().slice(0, 30);

  const payment = await prisma.payment.create({
    data: {
      orgId: parsedOrgId,
      invoiceId: parsedInvoiceId,
      provider: "SNIPPE",
      requestId,
      amount: outstandingAmount,
      currency: "TZS",
      status: "PENDING",
      paymentType: "MOBILE",
      channel: input.channel,
      apiVersion: SNIPPE_API_VERSION,
    },
  });

  try {
    const customer: {
      firstname: string;
      lastname: string;
      email?: string | undefined;
    } = {
      firstname: input.customer.firstname,
      lastname: input.customer.lastname,
    };

    if (input.customer.email) {
      customer.email = input.customer.email;
    }

    const providerResponse = await createSnippePayment(
      {
        payment_type: "mobile",
        details: {
          amount: Number(outstandingAmount.toFixed(0)),
          currency: "TZS",
        },
        phone_number: input.payerPhone,
        customer,
        webhook_url: buildWebhookUrl(),
        metadata: {
          invoice_id: input.invoiceId,
          org_id: orgId,
          payment_id: payment.id.toString(),
        },
      },
      requestId,
    );

    const responseData = providerResponse.data!;
    const providerReference = responseData.reference ?? null;

    if (!providerReference) {
      throw new HttpError(502, "Snippe payment response did not include a reference");
    }

    await prisma.payment.update({
      where: { id: payment.id },
      data: {
        reference: providerReference,
        externalReference: responseData.external_reference ?? null,
        status: mapSnippeStatus(responseData.status),
        apiVersion: responseData.api_version ?? SNIPPE_API_VERSION,
        expiresAt: responseData.expires_at ? new Date(responseData.expires_at) : null,
        rawResponse: providerResponse as Prisma.InputJsonValue,
      },
      include: {
        invoice: {
          select: {
            id: true,
            invoiceNo: true,
            branchId: true,
            student: {
              select: {
                id: true,
                fullName: true,
                admissionNo: true,
              },
            },
          },
        },
      },
    });

    const updatedPayment = await getPaymentWithInvoice(payment.id);

    await createAuditLog({
      orgId: parsedOrgId,
      actorUserId: parsedActorUserId,
      action: "payment.initiated",
      entityType: "payment",
      entityId: payment.id.toString(),
      metadata: buildInitiationAuditMetadata(input, requestId, payment.id, providerReference),
      ipAddress: ipAddress ?? null,
    });

    return toPaymentResponse(updatedPayment);
  } catch (error) {
    const mappedError =
      error instanceof Error && error.name === "SnippeProviderError"
        ? mapSnippeErrorToHttpError(error as SnippeProviderError)
        : error instanceof HttpError
          ? error
          : new HttpError(502, "Snippe payment initiation failed");

    await prisma.payment.update({
      where: { id: payment.id },
      data: {
        status: "FAILED",
        rawResponse: {
          error: mappedError.message,
          details: mappedError.details ?? null,
        } as Prisma.InputJsonValue,
      },
    });

    await createAuditLog({
      orgId: parsedOrgId,
      actorUserId: parsedActorUserId,
      action: "payment.initiation_failed",
      entityType: "payment",
      entityId: payment.id.toString(),
      metadata: {
        invoiceId: input.invoiceId,
        requestId,
        error: mappedError.message,
        details: mappedError.details ?? null,
      },
      ipAddress: ipAddress ?? null,
    });

    throw mappedError;
  }
};

export const getPaymentById = async (orgId: string, paymentId: string) => {
  const payment = await prisma.payment.findFirst({
    where: {
      id: BigInt(paymentId),
      orgId: BigInt(orgId),
    },
    include: {
      invoice: {
        select: {
          id: true,
          invoiceNo: true,
          branchId: true,
          student: {
            select: {
              id: true,
              fullName: true,
              admissionNo: true,
            },
          },
        },
      },
    },
  });

  if (!payment) {
    throw new HttpError(404, "Payment not found");
  }

  return toPaymentResponse(payment);
};

export const listPayments = async (orgId: string, query: ListPaymentsQuery) => {
  const where: Prisma.PaymentWhereInput = {
    orgId: BigInt(orgId),
  };

  if (query.invoiceId) where.invoiceId = BigInt(query.invoiceId);
  if (query.status) where.status = query.status;
  if (query.channel) where.channel = query.channel;

  if (query.dateFrom || query.dateTo) {
    where.createdAt = {};

    if (query.dateFrom) {
      where.createdAt.gte = new Date(`${query.dateFrom}T00:00:00.000Z`);
    }

    if (query.dateTo) {
      where.createdAt.lte = new Date(`${query.dateTo}T23:59:59.999Z`);
    }
  }

  if (query.studentId) {
    where.invoice = {
      studentId: BigInt(query.studentId),
    };
  }

  const records = await prisma.payment.findMany({
    where,
    orderBy: [{ createdAt: "desc" }],
    include: {
      invoice: {
        select: {
          id: true,
          invoiceNo: true,
          branchId: true,
          student: {
            select: {
              id: true,
              fullName: true,
              admissionNo: true,
            },
          },
        },
      },
    },
  });

  return records.map(toPaymentResponse);
};

export const getPaymentReceipt = async (orgId: string, paymentId: string) => {
  const payment = await prisma.payment.findFirst({
    where: {
      id: BigInt(paymentId),
      orgId: BigInt(orgId),
    },
    include: {
      organization: {
        select: {
          id: true,
          name: true,
          code: true,
        },
      },
      invoice: {
        select: {
          id: true,
          invoiceNo: true,
          amountDue: true,
          amountPaid: true,
          dueDate: true,
          status: true,
          branch: {
            select: {
              id: true,
              name: true,
            },
          },
          student: {
            select: {
              id: true,
              fullName: true,
              admissionNo: true,
            },
          },
        },
      },
    },
  });

  if (!payment) {
    throw new HttpError(404, "Payment not found");
  }

  if (payment.status !== "COMPLETED") {
    throw new HttpError(409, "Receipt is only available for completed payments");
  }

  return toPaymentReceiptResponse(payment);
};

export const reconcilePaymentById = async (
  orgId: string,
  paymentId: string,
  actorUserId?: string | null,
  ipAddress?: string,
) => {
  const payment = await prisma.payment.findFirst({
    where: {
      id: BigInt(paymentId),
      orgId: BigInt(orgId),
    },
    select: {
      id: true,
      orgId: true,
      reference: true,
      status: true,
    },
  });

  if (!payment) {
    throw new HttpError(404, "Payment not found");
  }

  if (!payment.reference) {
    throw new HttpError(409, "This payment does not have a provider reference yet");
  }

  try {
    const providerResponse = await getSnippePaymentStatus(payment.reference);
    const data = providerResponse.data!;

    const updated = await applyPaymentStateUpdate({
      paymentId: payment.id,
      source: "reconcile",
      sourceLabel: "manual_status_sync",
      actorUserId: actorUserId ? BigInt(actorUserId) : null,
      ipAddress: ipAddress ?? null,
      rawResponse: providerResponse as Prisma.InputJsonValue,
      status: data.status ?? null,
      externalReference: data.external_reference ?? null,
      completedAt: data.completed_at ?? null,
      expiresAt: data.expires_at ?? null,
      apiVersion: data.api_version ?? null,
      amountValue: data.amount?.value ?? null,
      metadata: {
        reference: data.reference ?? payment.reference,
        providerStatus: data.status ?? null,
      },
    });

    return toPaymentResponse(updated);
  } catch (error) {
    const mappedError =
      error instanceof Error && error.name === "SnippeProviderError"
        ? mapSnippeErrorToHttpError(error as SnippeProviderError)
        : error instanceof HttpError
          ? error
          : new HttpError(502, "Snippe reconciliation failed");

    await createAuditLog({
      orgId: payment.orgId,
      actorUserId: actorUserId ? BigInt(actorUserId) : null,
      action: "payment.reconcile_failed",
      entityType: "payment",
      entityId: payment.id.toString(),
      metadata: {
        reference: payment.reference,
        error: mappedError.message,
        details: mappedError.details ?? null,
      },
      ipAddress: ipAddress ?? null,
    });

    throw mappedError;
  }
};

export const reconcilePendingPayments = async (options?: {
  limit?: number;
  olderThanMinutes?: number;
}) => {
  const limit = options?.limit ?? 25;
  const olderThanMinutes = options?.olderThanMinutes ?? 5;
  const cutoff = new Date(Date.now() - olderThanMinutes * 60 * 1000);

  const pendingPayments = await prisma.payment.findMany({
    where: {
      provider: "SNIPPE",
      status: "PENDING",
      reference: {
        not: null,
      },
      createdAt: {
        lte: cutoff,
      },
    },
    orderBy: [{ createdAt: "asc" }],
    take: limit,
    select: {
      id: true,
      orgId: true,
    },
  });

  const summary = {
    scanned: pendingPayments.length,
    reconciled: 0,
    failed: 0,
    paymentIds: [] as string[],
  };

  for (const record of pendingPayments) {
    try {
      await reconcilePaymentById(record.orgId.toString(), record.id.toString());
      summary.reconciled += 1;
      summary.paymentIds.push(record.id.toString());
    } catch (error) {
      summary.failed += 1;
      console.error("Failed to reconcile payment", {
        paymentId: record.id.toString(),
        error: error instanceof Error ? error.message : error,
      });
    }
  }

  return summary;
};

export const handleSnippeWebhook = async (
  rawBodyBuffer: Buffer,
  headers: {
    signature?: string;
    timestamp?: string;
    eventType?: string;
  },
) => {
  const rawBody = rawBodyBuffer.toString("utf8");

  if (!rawBody) {
    throw new HttpError(400, "Webhook body is empty");
  }

  if (!headers.signature || !headers.timestamp) {
    throw new HttpError(400, "Missing webhook signature headers");
  }

  let payload: SnippeWebhookPayload;

  try {
    payload = JSON.parse(rawBody) as SnippeWebhookPayload;
  } catch {
    throw new HttpError(400, "Webhook body is not valid JSON");
  }

  const eventId = payload.id ?? null;
  const eventType = headers.eventType ?? payload.type ?? "unknown";
  const orgIdFromPayload = payload.data?.metadata?.org_id ? BigInt(payload.data.metadata.org_id) : null;

  const existingWebhook = eventId
    ? await prisma.paymentWebhook.findUnique({
        where: { eventId },
      })
    : null;

  if (existingWebhook?.processingStatus === "PROCESSED") {
    return {
      acknowledged: true,
      duplicate: true,
    };
  }

  verifySnippeWebhookSignature(headers.timestamp, headers.signature, rawBody);

  const webhook =
    existingWebhook ??
    (await prisma.paymentWebhook.create({
      data: {
        orgId: orgIdFromPayload,
        provider: "SNIPPE",
        eventType,
        eventId,
        apiVersion: payload.api_version ?? null,
        signature: headers.signature,
        webhookTimestamp: Number(headers.timestamp),
        payload: payload as Prisma.InputJsonValue,
        rawBody,
        processingStatus: "RECEIVED",
      },
    }));

  const payment = payload.data?.reference
    ? await prisma.payment.findUnique({
        where: {
          reference: payload.data.reference,
        },
        select: {
          id: true,
          orgId: true,
        },
      })
    : null;

  if (!payment) {
    await prisma.paymentWebhook.update({
      where: { id: webhook.id },
      data: {
        processingStatus: "IGNORED",
        processedAt: new Date(),
        errorMessage: "Payment reference not found",
      },
    });

    return {
      acknowledged: true,
      ignored: true,
    };
  }

  try {
    await applyPaymentStateUpdate({
      paymentId: payment.id,
      source: "webhook",
      sourceLabel: "snippe_webhook",
      eventType,
      rawResponse: payload as Prisma.InputJsonValue,
      status: payload.data?.status ?? null,
      externalReference: payload.data?.external_reference ?? null,
      completedAt: payload.data?.completed_at ?? null,
      apiVersion: payload.api_version ?? null,
      amountValue: payload.data?.amount?.value ?? null,
      metadata: {
        eventId,
        eventType,
        reference: payload.data?.reference ?? null,
      },
    });

    await prisma.paymentWebhook.update({
      where: { id: webhook.id },
      data: {
        orgId: payment.orgId,
        processingStatus: "PROCESSED",
        processedAt: new Date(),
        errorMessage: null,
      },
    });

    return {
      acknowledged: true,
      duplicate: false,
    };
  } catch (error) {
    await prisma.paymentWebhook.update({
      where: { id: webhook.id },
      data: {
        orgId: payment.orgId,
        processingStatus: "FAILED",
        processedAt: new Date(),
        errorMessage: error instanceof Error ? error.message : "Webhook processing failed",
      },
    });

    throw error;
  }
};
