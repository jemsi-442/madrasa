CREATE TABLE `course_modules` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `org_id` BIGINT NOT NULL,
  `course_id` BIGINT NOT NULL,
  `title` VARCHAR(150) NOT NULL,
  `position` INTEGER NOT NULL,
  `summary` VARCHAR(255) NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  UNIQUE INDEX `uniq_course_modules_course_position`(`course_id`, `position`),
  INDEX `idx_course_modules_org_course`(`org_id`, `course_id`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `course_lessons` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `org_id` BIGINT NOT NULL,
  `course_id` BIGINT NOT NULL,
  `module_id` BIGINT NOT NULL,
  `title` VARCHAR(150) NOT NULL,
  `slug` VARCHAR(150) NOT NULL,
  `summary` VARCHAR(255) NULL,
  `content_text` LONGTEXT NULL,
  `position` INTEGER NOT NULL,
  `visibility` ENUM('FREE', 'PAID', 'PREVIEW', 'LOCKED', 'UNLISTED') NOT NULL DEFAULT 'LOCKED',
  `publication_status` ENUM('DRAFT', 'PUBLISHED', 'ARCHIVED') NOT NULL DEFAULT 'DRAFT',
  `estimated_minutes` INTEGER NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  UNIQUE INDEX `uniq_course_lessons_course_slug`(`course_id`, `slug`),
  UNIQUE INDEX `uniq_course_lessons_module_position`(`module_id`, `position`),
  INDEX `idx_course_lessons_org_course_module`(`org_id`, `course_id`, `module_id`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `media_assets` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `org_id` BIGINT NOT NULL,
  `course_id` BIGINT NOT NULL,
  `lesson_id` BIGINT NOT NULL,
  `asset_type` ENUM('VIDEO', 'AUDIO', 'PDF', 'TEXT', 'ATTACHMENT') NOT NULL,
  `storage_provider` ENUM('LOCAL', 'S3', 'R2', 'VIMEO', 'YOUTUBE', 'EXTERNAL') NOT NULL DEFAULT 'LOCAL',
  `title` VARCHAR(150) NULL,
  `storage_key` VARCHAR(255) NOT NULL,
  `mime_type` VARCHAR(120) NULL,
  `duration_seconds` INTEGER NULL,
  `file_size_bytes` BIGINT NULL,
  `visibility` ENUM('FREE', 'PAID', 'PREVIEW', 'LOCKED', 'UNLISTED') NOT NULL DEFAULT 'LOCKED',
  `download_allowed` BOOLEAN NOT NULL DEFAULT false,
  `streaming_profile` VARCHAR(100) NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  INDEX `idx_media_assets_org_course_lesson`(`org_id`, `course_id`, `lesson_id`),
  INDEX `idx_media_assets_lesson_type`(`lesson_id`, `asset_type`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

ALTER TABLE `course_modules`
  ADD CONSTRAINT `fk_course_modules_org` FOREIGN KEY (`org_id`) REFERENCES `organizations`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_course_modules_course` FOREIGN KEY (`course_id`) REFERENCES `courses`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `course_lessons`
  ADD CONSTRAINT `fk_course_lessons_org` FOREIGN KEY (`org_id`) REFERENCES `organizations`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_course_lessons_course` FOREIGN KEY (`course_id`) REFERENCES `courses`(`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_course_lessons_module` FOREIGN KEY (`module_id`) REFERENCES `course_modules`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `media_assets`
  ADD CONSTRAINT `fk_media_assets_org` FOREIGN KEY (`org_id`) REFERENCES `organizations`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_media_assets_course` FOREIGN KEY (`course_id`) REFERENCES `courses`(`id`) ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT `fk_media_assets_lesson` FOREIGN KEY (`lesson_id`) REFERENCES `course_lessons`(`id`) ON DELETE CASCADE ON UPDATE CASCADE;
