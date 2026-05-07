import crypto from "node:crypto";

import { env } from "../../config/env";

type SnippeEnvelope<T> = {
  status?: string;
  code?: number;
  message?: string;
  error_code?: string;
  data?: T;
};

export type SnippeCreatePaymentPayload = {
  payment_type: "mobile";
  details: {
    amount: number;
    currency: "TZS";
  };
  phone_number: string;
  customer: {
    firstname: string;
    lastname: string;
    email?: string | undefined;
  };
  webhook_url: string;
  metadata: {
    invoice_id: string;
    org_id: string;
    payment_id: string;
  };
};

export type SnippePaymentRecord = {
  id?: string;
  reference?: string;
  status?: string;
  api_version?: string;
  expires_at?: string;
  completed_at?: string;
  external_reference?: string | null;
  payment_type?: string;
  amount?: {
    currency?: string;
    value?: number;
  };
  channel?: {
    provider?: string;
    type?: string;
  };
  customer?: {
    first_name?: string;
    last_name?: string;
    email?: string;
    phone?: string;
  };
  metadata?: Record<string, string>;
};

export class SnippeProviderError extends Error {
  public readonly httpStatus: number;
  public readonly providerCode: string | null;
  public readonly providerMessage: string;
  public readonly retryable: boolean;
  public readonly responseBody: unknown;

  constructor(input: {
    httpStatus: number;
    providerCode?: string | null;
    providerMessage: string;
    retryable: boolean;
    responseBody?: unknown;
  }) {
    super(input.providerMessage);
    this.name = "SnippeProviderError";
    this.httpStatus = input.httpStatus;
    this.providerCode = input.providerCode ?? null;
    this.providerMessage = input.providerMessage;
    this.retryable = input.retryable;
    this.responseBody = input.responseBody ?? null;
  }
}

const SNIPPE_API_VERSION = "2026-01-25";

const createMockReference = () => crypto.randomUUID();

const buildMockCreateResponse = (): SnippeEnvelope<SnippePaymentRecord> => ({
  status: "success",
  code: 201,
  data: {
    reference: createMockReference(),
    status: "pending",
    api_version: SNIPPE_API_VERSION,
    expires_at: new Date(Date.now() + 4 * 60 * 60 * 1000).toISOString(),
    payment_type: "mobile",
  },
});

const buildMockStatusResponse = (reference: string): SnippeEnvelope<SnippePaymentRecord> => ({
  status: "success",
  code: 200,
  data: {
    reference,
    status: "completed",
    api_version: SNIPPE_API_VERSION,
    completed_at: new Date().toISOString(),
    expires_at: new Date(Date.now() + 4 * 60 * 60 * 1000).toISOString(),
    external_reference: `MOCK-${reference.slice(0, 8).toUpperCase()}`,
    channel: {
      provider: "mock",
      type: "mobile_money",
    },
    payment_type: "mobile",
  },
});

const normalizeProviderError = (
  responseStatus: number,
  body: SnippeEnvelope<unknown> | unknown,
): SnippeProviderError => {
  const payload = typeof body === "object" && body !== null ? (body as SnippeEnvelope<unknown>) : {};
  const providerCode = payload.error_code ?? null;
  const providerMessage = payload.message ?? "Snippe request failed";
  const retryable = responseStatus === 429 || responseStatus >= 500;

  return new SnippeProviderError({
    httpStatus: responseStatus,
    providerCode,
    providerMessage,
    retryable,
    responseBody: body,
  });
};

const requestSnippe = async <T>(
  path: string,
  init: {
    method: "GET" | "POST";
    idempotencyKey?: string;
    body?: unknown;
  },
) => {
  if (env.SNIPPE_MOCK_MODE) {
    if (init.method === "POST" && path === "/v1/payments") {
      return buildMockCreateResponse() as SnippeEnvelope<T>;
    }

    if (init.method === "GET" && path.startsWith("/v1/payments/")) {
      const reference = path.split("/").at(-1) ?? "";
      return buildMockStatusResponse(reference) as SnippeEnvelope<T>;
    }
  }

  if (!env.SNIPPE_API_KEY) {
    throw new SnippeProviderError({
      httpStatus: 503,
      providerCode: "snippe_api_key_missing",
      providerMessage: "SNIPPE_API_KEY is not configured",
      retryable: false,
    });
  }

  let response: Response;
  const requestInit: RequestInit = {
    method: init.method,
    headers: {
      Authorization: `Bearer ${env.SNIPPE_API_KEY}`,
      "Content-Type": "application/json",
      ...(init.idempotencyKey ? { "Idempotency-Key": init.idempotencyKey } : {}),
    },
    signal: AbortSignal.timeout(15_000),
  };

  if (init.body) {
    requestInit.body = JSON.stringify(init.body);
  }

  try {
    response = await fetch(`${env.SNIPPE_BASE_URL}${path}`, requestInit);
  } catch (error) {
    throw new SnippeProviderError({
      httpStatus: 503,
      providerCode: "network_error",
      providerMessage: error instanceof Error ? error.message : "Unable to reach Snippe",
      retryable: true,
    });
  }

  let responseBody: unknown = null;

  try {
    responseBody = await response.json();
  } catch {
    if (!response.ok) {
      throw new SnippeProviderError({
        httpStatus: response.status || 502,
        providerCode: "invalid_json_response",
        providerMessage: "Snippe returned a non-JSON error response",
        retryable: response.status >= 500,
      });
    }
  }

  if (!response.ok) {
    throw normalizeProviderError(response.status || 502, responseBody);
  }

  return (responseBody ?? {}) as SnippeEnvelope<T>;
};

export const createSnippePayment = async (payload: SnippeCreatePaymentPayload, idempotencyKey: string) => {
  const response = await requestSnippe<SnippePaymentRecord>("/v1/payments", {
    method: "POST",
    idempotencyKey,
    body: payload,
  });

  if (!response.data?.reference) {
    throw new SnippeProviderError({
      httpStatus: 502,
      providerCode: "invalid_provider_response",
      providerMessage: "Snippe payment response did not include a reference",
      retryable: false,
      responseBody: response,
    });
  }

  return response;
};

export const getSnippePaymentStatus = async (reference: string) => {
  const response = await requestSnippe<SnippePaymentRecord>(`/v1/payments/${reference}`, {
    method: "GET",
  });

  if (!response.data?.reference) {
    throw new SnippeProviderError({
      httpStatus: 502,
      providerCode: "invalid_provider_response",
      providerMessage: "Snippe status response did not include a reference",
      retryable: false,
      responseBody: response,
    });
  }

  return response;
};
