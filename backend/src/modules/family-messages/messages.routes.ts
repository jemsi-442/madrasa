import { Router } from "express";
import { authenticate } from "../../shared/middleware/authenticate";
import { requireTenantContext } from "../../shared/middleware/tenant-context";
import { requireActiveSchoolAccount } from "../../shared/middleware/active-school-account";
import { requireRole } from "../../shared/middleware/require-role";
import { asyncHandler } from "../../shared/utils/async-handler";
import { jsonRecord } from "../../shared/utils/json-record";
import { conversationInput, historyQuery, inboxQuery, messageId, messageInput, readInput } from "./messages.schemas";
import { conversationHistory, markFamilyRead, messageContacts, messageInbox, openConversation, sendFamilyMessage } from "./messages.service";

export const familyMessagesRouter = Router();
familyMessagesRouter.use(authenticate, requireTenantContext, requireRole("PARENT", "TEACHER"), requireActiveSchoolAccount);
familyMessagesRouter.use((_req, res, next) => { res.setHeader("Cache-Control", "no-store"); next(); });
familyMessagesRouter.get("/contacts", asyncHandler(async (req, res) => {
  res.json({ success: true, data: jsonRecord(await messageContacts(req.authUser!, inboxQuery.parse(req.query))) });
}));
familyMessagesRouter.get("/conversations", asyncHandler(async (req, res) => {
  res.json({ success: true, data: jsonRecord(await messageInbox(req.authUser!, inboxQuery.parse(req.query))) });
}));
familyMessagesRouter.post("/conversations", asyncHandler(async (req, res) => {
  res.json({ success: true, data: jsonRecord(await openConversation(req.authUser!, conversationInput.parse(req.body))) });
}));
familyMessagesRouter.get("/conversations/:id", asyncHandler(async (req, res) => {
  res.json({ success: true, data: jsonRecord(await conversationHistory(req.authUser!, messageId.parse(req.params.id), historyQuery.parse(req.query).before)) });
}));
familyMessagesRouter.post("/conversations/:id/messages", asyncHandler(async (req, res) => {
  res.json({ success: true, data: jsonRecord(await sendFamilyMessage(req.authUser!, messageId.parse(req.params.id), messageInput.parse(req.body))) });
}));
familyMessagesRouter.post("/conversations/:id/read", asyncHandler(async (req, res) => {
  res.json({ success: true, data: jsonRecord(await markFamilyRead(req.authUser!, messageId.parse(req.params.id), readInput.parse(req.body).throughId)) });
}));
