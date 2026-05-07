CREATE TABLE `hifdh_progress` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `org_id` BIGINT NOT NULL,
  `student_id` BIGINT NOT NULL,
  `teacher_id` BIGINT NOT NULL,
  `juz_number` TINYINT NOT NULL,
  `surah_name` VARCHAR(100) NOT NULL,
  `ayah_from` INT NULL,
  `ayah_to` INT NULL,
  `memorization_score` DECIMAL(5, 2) NOT NULL,
  `revision_score` DECIMAL(5, 2) NULL,
  `remarks` TEXT NULL,
  `assessed_on` DATE NOT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  INDEX `idx_hifdh_org_student_assessed_on` (`org_id`, `student_id`, `assessed_on`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `announcements` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `org_id` BIGINT NOT NULL,
  `branch_id` BIGINT NULL,
  `title` VARCHAR(150) NOT NULL,
  `message` TEXT NOT NULL,
  `audience` ENUM('ALL', 'PARENTS', 'TEACHERS', 'ACCOUNTANTS') NOT NULL,
  `publish_at` DATETIME(3) NOT NULL,
  `expires_at` DATETIME(3) NULL,
  `created_by` BIGINT NOT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  INDEX `idx_announcements_org_branch_audience` (`org_id`, `branch_id`, `audience`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

ALTER TABLE `hifdh_progress`
  ADD CONSTRAINT `hifdh_progress_org_id_fkey`
  FOREIGN KEY (`org_id`) REFERENCES `organizations`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `hifdh_progress`
  ADD CONSTRAINT `hifdh_progress_student_id_fkey`
  FOREIGN KEY (`student_id`) REFERENCES `students`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `hifdh_progress`
  ADD CONSTRAINT `hifdh_progress_teacher_id_fkey`
  FOREIGN KEY (`teacher_id`) REFERENCES `users`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `announcements`
  ADD CONSTRAINT `announcements_org_id_fkey`
  FOREIGN KEY (`org_id`) REFERENCES `organizations`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `announcements`
  ADD CONSTRAINT `announcements_branch_id_fkey`
  FOREIGN KEY (`branch_id`) REFERENCES `branches`(`id`)
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE `announcements`
  ADD CONSTRAINT `announcements_created_by_fkey`
  FOREIGN KEY (`created_by`) REFERENCES `users`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;
