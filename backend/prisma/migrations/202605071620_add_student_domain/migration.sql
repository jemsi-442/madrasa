CREATE TABLE `guardians` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `org_id` BIGINT NOT NULL,
  `user_id` BIGINT NULL,
  `full_name` VARCHAR(150) NOT NULL,
  `phone` VARCHAR(30) NOT NULL,
  `email` VARCHAR(150) NULL,
  `relationship` VARCHAR(50) NULL,
  `address` VARCHAR(255) NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE INDEX `guardians_user_id_key` (`user_id`),
  INDEX `idx_guardians_org_phone` (`org_id`, `phone`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `classes` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `org_id` BIGINT NOT NULL,
  `branch_id` BIGINT NOT NULL,
  `name` VARCHAR(100) NOT NULL,
  `level` VARCHAR(100) NOT NULL,
  `academic_year` VARCHAR(20) NOT NULL,
  `teacher_id` BIGINT NULL,
  `capacity` INTEGER NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  INDEX `idx_classes_org_branch_year` (`org_id`, `branch_id`, `academic_year`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `subjects` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `org_id` BIGINT NOT NULL,
  `code` VARCHAR(30) NOT NULL,
  `name` VARCHAR(100) NOT NULL,
  `is_core` BOOLEAN NOT NULL DEFAULT true,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE INDEX `uniq_subjects_org_code` (`org_id`, `code`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `students` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `org_id` BIGINT NOT NULL,
  `branch_id` BIGINT NOT NULL,
  `admission_no` VARCHAR(50) NOT NULL,
  `full_name` VARCHAR(150) NOT NULL,
  `gender` VARCHAR(20) NOT NULL,
  `dob` DATE NULL,
  `status` ENUM('ACTIVE', 'INACTIVE', 'SUSPENDED', 'GRADUATED') NOT NULL DEFAULT 'ACTIVE',
  `class_id` BIGINT NULL,
  `primary_guardian_id` BIGINT NOT NULL,
  `joined_on` DATE NULL,
  `left_on` DATE NULL,
  `notes` TEXT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE INDEX `uniq_students_org_admission_no` (`org_id`, `admission_no`),
  INDEX `idx_students_org_branch_class` (`org_id`, `branch_id`, `class_id`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `student_guardians` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `org_id` BIGINT NOT NULL,
  `student_id` BIGINT NOT NULL,
  `guardian_id` BIGINT NOT NULL,
  `is_primary` BOOLEAN NOT NULL DEFAULT false,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE INDEX `uniq_student_guardian_pair` (`student_id`, `guardian_id`),
  INDEX `idx_student_guardians_org_guardian` (`org_id`, `guardian_id`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `enrollments` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `org_id` BIGINT NOT NULL,
  `student_id` BIGINT NOT NULL,
  `class_id` BIGINT NOT NULL,
  `academic_year` VARCHAR(20) NOT NULL,
  `status` ENUM('ACTIVE', 'COMPLETED', 'WITHDRAWN') NOT NULL DEFAULT 'ACTIVE',
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE INDEX `uniq_enrollment_student_class_year` (`student_id`, `class_id`, `academic_year`),
  INDEX `idx_enrollments_org_class_status` (`org_id`, `class_id`, `status`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

ALTER TABLE `guardians`
  ADD CONSTRAINT `guardians_org_id_fkey`
  FOREIGN KEY (`org_id`) REFERENCES `organizations`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `guardians`
  ADD CONSTRAINT `guardians_user_id_fkey`
  FOREIGN KEY (`user_id`) REFERENCES `users`(`id`)
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE `classes`
  ADD CONSTRAINT `classes_org_id_fkey`
  FOREIGN KEY (`org_id`) REFERENCES `organizations`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `classes`
  ADD CONSTRAINT `classes_branch_id_fkey`
  FOREIGN KEY (`branch_id`) REFERENCES `branches`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `classes`
  ADD CONSTRAINT `classes_teacher_id_fkey`
  FOREIGN KEY (`teacher_id`) REFERENCES `users`(`id`)
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE `subjects`
  ADD CONSTRAINT `subjects_org_id_fkey`
  FOREIGN KEY (`org_id`) REFERENCES `organizations`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `students`
  ADD CONSTRAINT `students_org_id_fkey`
  FOREIGN KEY (`org_id`) REFERENCES `organizations`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `students`
  ADD CONSTRAINT `students_branch_id_fkey`
  FOREIGN KEY (`branch_id`) REFERENCES `branches`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `students`
  ADD CONSTRAINT `students_class_id_fkey`
  FOREIGN KEY (`class_id`) REFERENCES `classes`(`id`)
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE `students`
  ADD CONSTRAINT `students_primary_guardian_id_fkey`
  FOREIGN KEY (`primary_guardian_id`) REFERENCES `guardians`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `student_guardians`
  ADD CONSTRAINT `student_guardians_student_id_fkey`
  FOREIGN KEY (`student_id`) REFERENCES `students`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `student_guardians`
  ADD CONSTRAINT `student_guardians_guardian_id_fkey`
  FOREIGN KEY (`guardian_id`) REFERENCES `guardians`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `enrollments`
  ADD CONSTRAINT `enrollments_org_id_fkey`
  FOREIGN KEY (`org_id`) REFERENCES `organizations`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `enrollments`
  ADD CONSTRAINT `enrollments_student_id_fkey`
  FOREIGN KEY (`student_id`) REFERENCES `students`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `enrollments`
  ADD CONSTRAINT `enrollments_class_id_fkey`
  FOREIGN KEY (`class_id`) REFERENCES `classes`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

