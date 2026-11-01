ALTER TABLE `donors`
 ADD COLUMN `sms_opt_in` BOOLEAN NOT NULL DEFAULT false,
 ADD COLUMN `sms_consent_note` VARCHAR(500) NULL,
 ADD COLUMN `sms_consent_by` VARCHAR(30) NULL,
 ADD COLUMN `sms_consent_at` DATETIME(3) NULL;
CREATE TABLE `donor_messages` (
 `id` VARCHAR(30) NOT NULL PRIMARY KEY,
 `creator_id` VARCHAR(30) NOT NULL,
 `sender_name` VARCHAR(150) NOT NULL,
 `body` TEXT NOT NULL,
 `status` VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
 `revision` INTEGER NOT NULL DEFAULT 1,
 `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
 `updated_at` DATETIME(3) NOT NULL,
 `queued_at` DATETIME(3) NULL,
 INDEX `donor_messages_creator_id_status_created_at_idx` (`creator_id`, `status`, `created_at`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE TABLE `donor_message_recipients` (
 `id` BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
 `message_id` VARCHAR(30) NOT NULL,
 `donor_id` BIGINT NOT NULL,
 `donor_name` VARCHAR(150) NOT NULL,
 `madrasa_name` VARCHAR(150) NOT NULL,
 `phone` VARCHAR(30) NOT NULL,
 `status` VARCHAR(20) NOT NULL DEFAULT 'DRAFT',
 `batch_id` VARCHAR(150) NULL,
 `reason` VARCHAR(50) NULL,
 `updated_at` DATETIME(3) NOT NULL,
 UNIQUE INDEX `donor_message_recipients_message_id_donor_id_key` (`message_id`, `donor_id`),
 INDEX `donor_message_recipients_status_id_idx` (`status`, `id`),
 CONSTRAINT `donor_message_recipients_message_id_fkey` FOREIGN KEY (`message_id`) REFERENCES `donor_messages` (`id`) ON DELETE CASCADE ON UPDATE CASCADE,
 CONSTRAINT `donor_message_recipients_donor_id_fkey` FOREIGN KEY (`donor_id`) REFERENCES `donors` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
