CREATE TABLE `attendance_records` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `org_id` BIGINT NOT NULL,
  `branch_id` BIGINT NOT NULL,
  `class_id` BIGINT NOT NULL,
  `student_id` BIGINT NOT NULL,
  `date` DATE NOT NULL,
  `status` ENUM('PRESENT', 'ABSENT', 'LATE', 'EXCUSED') NOT NULL,
  `reason` VARCHAR(255) NULL,
  `marked_by` BIGINT NOT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE INDEX `uniq_attendance_org_student_date` (`org_id`, `student_id`, `date`),
  INDEX `idx_attendance_org_class_date` (`org_id`, `class_id`, `date`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

ALTER TABLE `attendance_records`
  ADD CONSTRAINT `attendance_records_org_id_fkey`
  FOREIGN KEY (`org_id`) REFERENCES `organizations`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `attendance_records`
  ADD CONSTRAINT `attendance_records_branch_id_fkey`
  FOREIGN KEY (`branch_id`) REFERENCES `branches`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `attendance_records`
  ADD CONSTRAINT `attendance_records_class_id_fkey`
  FOREIGN KEY (`class_id`) REFERENCES `classes`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `attendance_records`
  ADD CONSTRAINT `attendance_records_student_id_fkey`
  FOREIGN KEY (`student_id`) REFERENCES `students`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `attendance_records`
  ADD CONSTRAINT `attendance_records_marked_by_fkey`
  FOREIGN KEY (`marked_by`) REFERENCES `users`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

