CREATE TABLE `course_lesson_progress` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `org_id` BIGINT NOT NULL,
  `course_id` BIGINT NOT NULL,
  `lesson_id` BIGINT NOT NULL,
  `student_id` BIGINT NOT NULL,
  `learner_user_id` BIGINT NOT NULL,
  `watch_seconds` INTEGER NOT NULL DEFAULT 0,
  `progress_percent` INTEGER NOT NULL DEFAULT 0,
  `completed_at` DATETIME(3) NULL,
  `last_opened_at` DATETIME(3) NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  UNIQUE INDEX `uniq_course_lesson_progress_lesson_learner`(`lesson_id`, `learner_user_id`),
  INDEX `idx_course_lesson_progress_org_learner_course`(`org_id`, `learner_user_id`, `course_id`),
  INDEX `idx_course_lesson_progress_org_student`(`org_id`, `student_id`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

ALTER TABLE `course_lesson_progress`
  ADD CONSTRAINT `course_lesson_progress_org_id_fkey`
    FOREIGN KEY (`org_id`) REFERENCES `organizations`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT `course_lesson_progress_course_id_fkey`
    FOREIGN KEY (`course_id`) REFERENCES `courses`(`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `course_lesson_progress_lesson_id_fkey`
    FOREIGN KEY (`lesson_id`) REFERENCES `course_lessons`(`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `course_lesson_progress_student_id_fkey`
    FOREIGN KEY (`student_id`) REFERENCES `students`(`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `course_lesson_progress_learner_user_id_fkey`
    FOREIGN KEY (`learner_user_id`) REFERENCES `users`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
