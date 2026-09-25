CREATE TABLE `course_access_grants` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `org_id` BIGINT NOT NULL,
  `course_id` BIGINT NOT NULL,
  `student_id` BIGINT NOT NULL,
  `learner_user_id` BIGINT NOT NULL,
  `grant_type` ENUM('MANUAL', 'PAYMENT', 'SCHOLARSHIP', 'PREVIEW') NOT NULL DEFAULT 'MANUAL',
  `starts_at` DATETIME(3) NULL,
  `ends_at` DATETIME(3) NULL,
  `granted_by_user_id` BIGINT NOT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  UNIQUE INDEX `uniq_course_access_course_learner`(`course_id`, `learner_user_id`),
  INDEX `idx_course_access_org_learner`(`org_id`, `learner_user_id`),
  INDEX `idx_course_access_org_student`(`org_id`, `student_id`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

ALTER TABLE `course_access_grants`
  ADD CONSTRAINT `fk_course_access_org` FOREIGN KEY (`org_id`) REFERENCES `organizations`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_course_access_course` FOREIGN KEY (`course_id`) REFERENCES `courses`(`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_course_access_student` FOREIGN KEY (`student_id`) REFERENCES `students`(`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_course_access_learner_user` FOREIGN KEY (`learner_user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_course_access_granted_by` FOREIGN KEY (`granted_by_user_id`) REFERENCES `users`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;
