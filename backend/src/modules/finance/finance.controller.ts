import type { Request, Response } from "express";

import {
  createExpenseSchema,
  createFeeStructureSchema,
  createInvoiceSchema,
  listExpensesQuerySchema,
  listFeeStructuresQuerySchema,
  listInvoicesQuerySchema,
} from "./finance.schemas";
import {
  createExpense,
  createFeeStructure,
  createInvoice,
  listExpenses,
  listFeeStructures,
  listInvoices,
} from "./finance.service";

export const createFeeStructureHandler = async (req: Request, res: Response) => {
  const input = createFeeStructureSchema.parse(req.body);
  const record = await createFeeStructure(req.authUser!, input);

  res.status(201).json({
    success: true,
    message: "Fee structure created successfully",
    data: record,
  });
};

export const listFeeStructuresHandler = async (req: Request, res: Response) => {
  const query = listFeeStructuresQuerySchema.parse(req.query);
  const records = await listFeeStructures(req.authUser!, query);

  res.status(200).json({
    success: true,
    message: "Fee structures loaded successfully",
    data: records,
  });
};

export const createInvoiceHandler = async (req: Request, res: Response) => {
  const input = createInvoiceSchema.parse(req.body);
  const record = await createInvoice(req.authUser!, input);

  res.status(201).json({
    success: true,
    message: "Invoice created successfully",
    data: record,
  });
};

export const listInvoicesHandler = async (req: Request, res: Response) => {
  const query = listInvoicesQuerySchema.parse(req.query);
  const records = await listInvoices(req.authUser!, query);

  res.status(200).json({
    success: true,
    message: "Invoices loaded successfully",
    data: records,
  });
};

export const createExpenseHandler = async (req: Request, res: Response) => {
  const input = createExpenseSchema.parse(req.body);
  const record = await createExpense(req.authUser!, input);

  res.status(201).json({
    success: true,
    message: "Expense created successfully",
    data: record,
  });
};

export const listExpensesHandler = async (req: Request, res: Response) => {
  const query = listExpensesQuerySchema.parse(req.query);
  const records = await listExpenses(req.authUser!, query);

  res.status(200).json({
    success: true,
    message: "Expenses loaded successfully",
    data: records,
  });
};
