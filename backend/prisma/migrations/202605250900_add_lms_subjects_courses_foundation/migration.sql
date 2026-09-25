ALTER TABLE `subjects`
  ADD COLUMN `slug` VARCHAR(100) NULL AFTER `code`,
  ADD COLUMN `summary` VARCHAR(255) NULL AFTER `name`,
  ADD COLUMN `category` ENUM('RELIGIOUS', 'LANGUAGE', 'TECHNICAL', 'BUSINESS', 'GENERAL', 'VOCATIONAL') NOT NULL DEFAULT 'GENERAL' AFTER `summary`,
  ADD COLUMN `is_active` BOOLEAN NOT NULL DEFAULT true AFTER `is_core`,
  ADD COLUMN `created_by_user_id` BIGINT NULL AFTER `is_active`,
  ADD CONSTRAINT `fk_subjects_created_by_user_id`
    FOREIGN KEY (`created_by_user_id`) REFERENCES `users`(`id`)
    ON DELETE SET NULL ON UPDATE CASCADE;

CREATE UNIQUE INDEX `uniq_subjects_org_slug` ON `subjects`(`org_id`, `slug`);

CREATE TABLE `courses` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `org_id` BIGINT NOT NULL,
  `subject_id` BIGINT NOT NULL,
  `slug` VARCHAR(120) NOT NULL,
  `title` VARCHAR(150) NOT NULL,
  `summary` VARCHAR(255) NOT NULL,
  `description` TEXT NULL,
  `program_category` ENUM('MADRASA_CHILD', 'COURSE_STUDENT') NOT NULL DEFAULT 'COURSE_STUDENT',
  `delivery_mode` ENUM('SELF_PACED', 'COHORT', 'LIVE_PLUS_LIBRARY') NOT NULL DEFAULT 'SELF_PACED',
  `level` VARCHAR(50) NULL,
  `visibility` ENUM('FREE', 'PAID', 'PREVIEW', 'LOCKED', 'UNLISTED') NOT NULL DEFAULT 'LOCKED',
  `publication_status` ENUM('DRAFT', 'PUBLISHED', 'ARCHIVED') NOT NULL DEFAULT 'DRAFT',
  `is_featured` BOOLEAN NOT NULL DEFAULT false,
  `is_religious` BOOLEAN NOT NULL DEFAULT false,
  `requires_approval_before_publish` BOOLEAN NOT NULL DEFAULT true,
  `primary_instructor_user_id` BIGINT NULL,
  `created_by_user_id` BIGINT NOT NULL,
  `published_by_user_id` BIGINT NULL,
  `published_at` DATETIME(3) NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  CONSTRAINT `fk_courses_org_id` FOREIGN KEY (`org_id`) REFERENCES `organizations`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_courses_subject_id` FOREIGN KEY (`subject_id`) REFERENCES `subjects`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_courses_primary_instructor_user_id` FOREIGN KEY (`primary_instructor_user_id`) REFERENCES `users`(`id`) ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT `fk_courses_created_by_user_id` FOREIGN KEY (`created_by_user_id`) REFERENCES `users`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_courses_published_by_user_id` FOREIGN KEY (`published_by_user_id`) REFERENCES `users`(`id`) ON DELETE SET NULL ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE UNIQUE INDEX `uniq_courses_org_slug` ON `courses`(`org_id`, `slug`);
CREATE INDEX `idx_courses_org_subject_status` ON `courses`(`org_id`, `subject_id`, `publication_status`);
CREATE INDEX `idx_courses_org_instructor` ON `courses`(`org_id`, `primary_instructor_user_id`);
