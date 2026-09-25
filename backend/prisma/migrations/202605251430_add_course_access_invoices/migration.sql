ALTER TABLE `invoices`
  ADD COLUMN `learner_user_id` BIGINT NULL,
  ADD COLUMN `course_id` BIGINT NULL,
  ADD COLUMN `course_access_request_id` BIGINT NULL,
  ADD COLUMN `invoice_scope` ENUM('SCHOOL_FEE', 'COURSE_ACCESS') NOT NULL DEFAULT 'SCHOOL_FEE';

CREATE INDEX `idx_invoices_org_learner_scope` ON `invoices`(`org_id`, `learner_user_id`, `invoice_scope`);
CREATE INDEX `idx_invoices_org_course_scope` ON `invoices`(`org_id`, `course_id`, `invoice_scope`);
CREATE INDEX `idx_invoices_org_course_request` ON `invoices`(`org_id`, `course_access_request_id`);

ALTER TABLE `invoices`
  ADD CONSTRAINT `invoices_learner_user_id_fkey`
    FOREIGN KEY (`learner_user_id`) REFERENCES `users`(`id`)
    ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `invoices_course_id_fkey`
    FOREIGN KEY (`course_id`) REFERENCES `courses`(`id`)
    ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT `invoices_course_access_request_id_fkey`
    FOREIGN KEY (`course_access_request_id`) REFERENCES `course_access_requests`(`id`)
    ON DELETE SET NULL ON UPDATE CASCADE;
