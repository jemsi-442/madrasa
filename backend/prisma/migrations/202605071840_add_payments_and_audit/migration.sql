CREATE TABLE `payments` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `org_id` BIGINT NOT NULL,
  `invoice_id` BIGINT NOT NULL,
  `provider` ENUM('SNIPPE', 'MANUAL') NOT NULL,
  `reference` VARCHAR(100) NULL,
  `external_reference` VARCHAR(100) NULL,
  `provider_txn_ref` VARCHAR(100) NULL,
  `request_id` VARCHAR(100) NULL,
  `amount` DECIMAL(12,2) NOT NULL,
  `currency` CHAR(3) NOT NULL DEFAULT 'TZS',
  `status` ENUM('PENDING', 'COMPLETED', 'FAILED', 'VOIDED', 'EXPIRED') NOT NULL DEFAULT 'PENDING',
  `payment_type` ENUM('MOBILE', 'CARD', 'DYNAMIC_QR', 'MANUAL') NOT NULL DEFAULT 'MOBILE',
  `channel` VARCHAR(50) NULL,
  `api_version` VARCHAR(20) NULL,
  `expires_at` DATETIME(3) NULL,
  `paid_at` DATETIME(3) NULL,
  `raw_response` JSON NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE INDEX `uniq_payments_reference` (`reference`),
  UNIQUE INDEX `uniq_payments_provider_txn_ref` (`provider_txn_ref`),
  INDEX `idx_payments_org_invoice_status` (`org_id`, `invoice_id`, `status`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `payment_webhooks` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `org_id` BIGINT NULL,
  `provider` ENUM('SNIPPE', 'MANUAL') NOT NULL,
  `event_type` VARCHAR(100) NOT NULL,
  `event_id` VARCHAR(100) NULL,
  `api_version` VARCHAR(20) NULL,
  `signature` VARCHAR(255) NULL,
  `webhook_timestamp` BIGINT NULL,
  `payload` JSON NOT NULL,
  `raw_body` LONGTEXT NOT NULL,
  `processing_status` ENUM('RECEIVED', 'PROCESSED', 'IGNORED', 'FAILED') NOT NULL DEFAULT 'RECEIVED',
  `received_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `processed_at` DATETIME(3) NULL,
  `error_message` TEXT NULL,
  UNIQUE INDEX `uniq_payment_webhooks_event_id` (`event_id`),
  INDEX `idx_payment_webhooks_provider_status` (`provider`, `processing_status`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `audit_logs` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `org_id` BIGINT NOT NULL,
  `actor_user_id` BIGINT NULL,
  `action` VARCHAR(100) NOT NULL,
  `entity_type` VARCHAR(100) NOT NULL,
  `entity_id` VARCHAR(100) NOT NULL,
  `metadata` JSON NULL,
  `ip_address` VARCHAR(64) NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  INDEX `idx_audit_logs_org_entity` (`org_id`, `entity_type`, `entity_id`),
  INDEX `idx_audit_logs_org_action_created_at` (`org_id`, `action`, `created_at`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

ALTER TABLE `payments`
  ADD CONSTRAINT `payments_org_id_fkey`
  FOREIGN KEY (`org_id`) REFERENCES `organizations`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `payments`
  ADD CONSTRAINT `payments_invoice_id_fkey`
  FOREIGN KEY (`invoice_id`) REFERENCES `invoices`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `payment_webhooks`
  ADD CONSTRAINT `payment_webhooks_org_id_fkey`
  FOREIGN KEY (`org_id`) REFERENCES `organizations`(`id`)
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE `audit_logs`
  ADD CONSTRAINT `audit_logs_org_id_fkey`
  FOREIGN KEY (`org_id`) REFERENCES `organizations`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `audit_logs`
  ADD CONSTRAINT `audit_logs_actor_user_id_fkey`
  FOREIGN KEY (`actor_user_id`) REFERENCES `users`(`id`)
  ON DELETE SET NULL ON UPDATE CASCADE;

