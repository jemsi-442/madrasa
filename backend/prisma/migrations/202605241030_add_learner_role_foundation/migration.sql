ALTER TABLE `users`
  MODIFY `role` ENUM('ADMIN', 'ACCOUNTANT', 'TEACHER', 'PARENT', 'LEARNER') NOT NULL;

ALTER TABLE `students`
  ADD COLUMN `program_category` ENUM('MADRASA_CHILD', 'COURSE_STUDENT') NOT NULL DEFAULT 'MADRASA_CHILD' AFTER `gender`,
  ADD COLUMN `learner_user_id` BIGINT NULL AFTER `class_id`;

ALTER TABLE `students`
  ADD CONSTRAINT `fk_students_learner_user_id`
    FOREIGN KEY (`learner_user_id`) REFERENCES `users`(`id`)
    ON DELETE SET NULL
    ON UPDATE CASCADE;

CREATE UNIQUE INDEX `uniq_students_learner_user_id` ON `students`(`learner_user_id`);
