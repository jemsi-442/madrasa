ALTER TABLE `courses`
  ADD COLUMN `price_amount` DECIMAL(12, 2) NULL,
  ADD COLUMN `currency` CHAR(3) NOT NULL DEFAULT 'TZS',
  ADD COLUMN `billing_mode` ENUM('ONE_TIME', 'SUBSCRIPTION') NOT NULL DEFAULT 'ONE_TIME';

CREATE TABLE `course_access_requests` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `org_id` BIGINT NOT NULL,
  `course_id` BIGINT NOT NULL,
  `student_id` BIGINT NOT NULL,
  `learner_user_id` BIGINT NOT NULL,
  `status` ENUM('NEW', 'REVIEWING', 'APPROVED', 'REJECTED') NOT NULL DEFAULT 'NEW',
  `request_message` VARCHAR(255) NULL,
  `reviewed_by_user_id` BIGINT NULL,
  `reviewed_at` DATETIME(3) NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  UNIQUE INDEX `uniq_course_access_request_course_learner`(`course_id`, `learner_user_id`),
  INDEX `idx_course_access_requests_org_status_created`(`org_id`, `status`, `created_at`),
  INDEX `idx_course_access_requests_org_student`(`org_id`, `student_id`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

ALTER TABLE `course_access_requests`
  ADD CONSTRAINT `course_access_requests_org_id_fkey`
    FOREIGN KEY (`org_id`) REFERENCES `organizations`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT `course_access_requests_course_id_fkey`
    FOREIGN KEY (`course_id`) REFERENCES `courses`(`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `course_access_requests_student_id_fkey`
    FOREIGN KEY (`student_id`) REFERENCES `students`(`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `course_access_requests_learner_user_id_fkey`
    FOREIGN KEY (`learner_user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `course_access_requests_reviewed_by_user_id_fkey`
    FOREIGN KEY (`reviewed_by_user_id`) REFERENCES `users`(`id`) ON DELETE SET NULL ON UPDATE CASCADE;
