CREATE TABLE `public_inquiries` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `org_id` BIGINT NOT NULL,
  `branch_id` BIGINT NULL,
  `inquiry_type` ENUM('GENERAL', 'ADMISSIONS', 'PARENT_SUPPORT', 'FINANCE') NOT NULL,
  `status` ENUM('NEW', 'CONTACTED', 'CLOSED') NOT NULL DEFAULT 'NEW',
  `full_name` VARCHAR(150) NOT NULL,
  `phone` VARCHAR(30) NOT NULL,
  `email` VARCHAR(150) NULL,
  `subject` VARCHAR(160) NOT NULL,
  `message` TEXT NOT NULL,
  `preferred_contact` VARCHAR(30) NULL,
  `source_page` VARCHAR(50) NOT NULL,
  `resolved_at` DATETIME(3) NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

  INDEX `idx_public_inquiries_org_type_status_created_at`(`org_id`, `inquiry_type`, `status`, `created_at`),
  INDEX `idx_public_inquiries_org_phone`(`org_id`, `phone`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

ALTER TABLE `public_inquiries`
  ADD CONSTRAINT `public_inquiries_org_id_fkey`
    FOREIGN KEY (`org_id`) REFERENCES `organizations`(`id`)
    ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `public_inquiries`
  ADD CONSTRAINT `public_inquiries_branch_id_fkey`
    FOREIGN KEY (`branch_id`) REFERENCES `branches`(`id`)
    ON DELETE SET NULL ON UPDATE CASCADE;
