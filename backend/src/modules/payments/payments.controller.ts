import type { Request, Response } from "express";

import { HttpError } from "../../shared/errors/http-error";
import {
  getPaymentById,
  getPaymentReceipt,
  handleSnippeWebhook,
  initiatePayment,
  listPayments,
  reconcilePaymentById,
} from "./payments.service";
import { initiatePaymentSchema, listPaymentsQuerySchema } from "./payments.schemas";

export const initiatePaymentHandler = async (req: Request, res: Response) => {
  const input = initiatePaymentSchema.parse(req.body);
  const payment = await initiatePayment(req.authUser!, input, req.ip);

  res.status(201).json({
    success: true,
    message: "Payment request submitted",
    data: payment,
  });
};

export const listPaymentsHandler = async (req: Request, res: Response) => {
  const query = listPaymentsQuerySchema.parse(req.query);
  const payments = await listPayments(req.authUser!, query);

  res.status(200).json({
    success: true,
    message: "Payments loaded successfully",
    data: payments,
  });
};

export const getPaymentByIdHandler = async (req: Request, res: Response) => {
  const paymentId = req.params.id;

  if (!paymentId) {
    throw new HttpError(400, "Payment id parameter is required");
  }

  const payment = await getPaymentById(req.authUser!, paymentId);

  res.status(200).json({
    success: true,
    message: "Payment loaded successfully",
    data: payment,
  });
};

export const getPaymentReceiptHandler = async (req: Request, res: Response) => {
  const paymentId = req.params.id;

  if (!paymentId) {
    throw new HttpError(400, "Payment id parameter is required");
  }

  const receipt = await getPaymentReceipt(req.authUser!, paymentId);

  res.status(200).json({
    success: true,
    message: "Payment receipt loaded successfully",
    data: receipt,
  });
};

export const reconcilePaymentHandler = async (req: Request, res: Response) => {
  const paymentId = req.params.id;

  if (!paymentId) {
    throw new HttpError(400, "Payment id parameter is required");
  }

  const payment = await reconcilePaymentById(req.authUser!, paymentId, req.ip);

  res.status(200).json({
    success: true,
    message: "Payment reconciled successfully",
    data: payment,
  });
};

export const snippeWebhookHandler = async (req: Request, res: Response) => {
  if (!Buffer.isBuffer(req.body)) {
    throw new HttpError(400, "Webhook body must be raw bytes");
  }

  const headers: {
    signature?: string;
    timestamp?: string;
    eventType?: string;
  } = {};

  const signature = req.header("X-Webhook-Signature");
  const timestamp = req.header("X-Webhook-Timestamp");
  const eventType = req.header("X-Webhook-Event");

  if (signature) headers.signature = signature;
  if (timestamp) headers.timestamp = timestamp;
  if (eventType) headers.eventType = eventType;

  const result = await handleSnippeWebhook(req.body, headers);

  res.status(200).json({
    success: true,
    message: "Webhook processed",
    data: result,
  });
};
