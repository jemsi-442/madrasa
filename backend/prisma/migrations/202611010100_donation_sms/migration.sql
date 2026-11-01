CREATE TABLE `donation_sms` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `donation_id` BIGINT NOT NULL,
  `status` VARCHAR(20) NOT NULL DEFAULT 'PENDING',
  `batch_id` VARCHAR(150) NULL,
  `reason` VARCHAR(50) NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE INDEX `donation_sms_donation_id_key` (`donation_id`),
  INDEX `donation_sms_status_created_at_idx` (`status`, `created_at`),
  CONSTRAINT `donation_sms_donation_id_fkey` FOREIGN KEY (`donation_id`)
    REFERENCES `donations` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
