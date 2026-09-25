import request from "supertest";

import { createApp } from "../../src/app/create-app";

const DEFAULT_ADMIN_LOGIN =
  process.env.TEST_ADMIN_LOGIN ?? process.env.SMOKE_ADMIN_LOGIN ?? "admin@example.com";
const DEFAULT_ADMIN_PASSWORD =
  process.env.TEST_ADMIN_PASSWORD ?? process.env.SMOKE_ADMIN_PASSWORD ?? "ChangeMe123!";
const DEFAULT_ACCOUNTANT_LOGIN =
  process.env.TEST_ACCOUNTANT_LOGIN ?? process.env.E2E_ACCOUNTANT_LOGIN ?? "accountant@example.com";
const DEFAULT_ACCOUNTANT_PASSWORD =
  process.env.TEST_ACCOUNTANT_PASSWORD ?? process.env.E2E_ACCOUNTANT_PASSWORD ?? "ChangeMe123!";
const DEFAULT_TEACHER_LOGIN =
  process.env.TEST_TEACHER_LOGIN ?? process.env.E2E_TEACHER_LOGIN ?? "teacher@example.com";
const DEFAULT_TEACHER_PASSWORD =
  process.env.TEST_TEACHER_PASSWORD ?? process.env.E2E_TEACHER_PASSWORD ?? "ChangeMe123!";
const DEFAULT_PARENT_LOGIN =
  process.env.TEST_PARENT_LOGIN ?? process.env.E2E_PARENT_LOGIN ?? "parent@example.com";
const DEFAULT_PARENT_PASSWORD =
  process.env.TEST_PARENT_PASSWORD ?? process.env.E2E_PARENT_PASSWORD ?? "ChangeMe123!";
const DEFAULT_LEARNER_LOGIN =
  process.env.TEST_LEARNER_LOGIN ?? process.env.E2E_LEARNER_LOGIN ?? "learner@example.com";
const DEFAULT_LEARNER_PASSWORD =
  process.env.TEST_LEARNER_PASSWORD ?? process.env.E2E_LEARNER_PASSWORD ?? "ChangeMe123!";

export const testAdminCredentials = {
  login: DEFAULT_ADMIN_LOGIN,
  password: DEFAULT_ADMIN_PASSWORD,
};

export const testAccountantCredentials = {
  login: DEFAULT_ACCOUNTANT_LOGIN,
  password: DEFAULT_ACCOUNTANT_PASSWORD,
};

export const testTeacherCredentials = {
  login: DEFAULT_TEACHER_LOGIN,
  password: DEFAULT_TEACHER_PASSWORD,
};

export const testParentCredentials = {
  login: DEFAULT_PARENT_LOGIN,
  password: DEFAULT_PARENT_PASSWORD,
};

export const testLearnerCredentials = {
  login: DEFAULT_LEARNER_LOGIN,
  password: DEFAULT_LEARNER_PASSWORD,
};

export const api = request(createApp());

export const loginAsAdmin = () => api.post("/api/auth/login").send(testAdminCredentials);
export const loginAsAccountant = () => api.post("/api/auth/login").send(testAccountantCredentials);
export const loginAsTeacher = () => api.post("/api/auth/login").send(testTeacherCredentials);
export const loginAsParent = () => api.post("/api/auth/login").send(testParentCredentials);
export const loginAsLearner = () => api.post("/api/auth/login").send(testLearnerCredentials);
