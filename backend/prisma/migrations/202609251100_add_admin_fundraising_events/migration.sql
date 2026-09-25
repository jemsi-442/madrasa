-- CreateTable
CREATE TABLE `donors` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `org_id` BIGINT NOT NULL,
    `full_name` VARCHAR(150) NOT NULL,
    `email` VARCHAR(150) NULL,
    `phone` VARCHAR(30) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,

    INDEX `idx_donors_org_name`(`org_id`, `full_name`),
    UNIQUE INDEX `uniq_donors_org_id`(`org_id`, `id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `fundraising_campaigns` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `org_id` BIGINT NOT NULL,
    `title` VARCHAR(150) NOT NULL,
    `description` VARCHAR(1000) NULL,
    `goal_amount` DECIMAL(12, 2) NOT NULL,
    `currency` CHAR(3) NOT NULL DEFAULT 'TZS',
    `status` ENUM('ACTIVE', 'CLOSED') NOT NULL DEFAULT 'ACTIVE',
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,

    INDEX `idx_campaigns_org_status`(`org_id`, `status`),
    UNIQUE INDEX `uniq_campaigns_org_id`(`org_id`, `id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `donation_pledges` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `org_id` BIGINT NOT NULL,
    `donor_id` BIGINT NOT NULL,
    `campaign_id` BIGINT NOT NULL,
    `amount` DECIMAL(12, 2) NOT NULL,
    `currency` CHAR(3) NOT NULL DEFAULT 'TZS',
    `due_on` DATE NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `idx_pledges_org_due`(`org_id`, `due_on`),
    UNIQUE INDEX `uniq_pledges_org_id`(`org_id`, `id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `donations` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `org_id` BIGINT NOT NULL,
    `donor_id` BIGINT NOT NULL,
    `campaign_id` BIGINT NOT NULL,
    `pledge_id` BIGINT NULL,
    `amount` DECIMAL(12, 2) NOT NULL,
    `currency` CHAR(3) NOT NULL DEFAULT 'TZS',
    `method` ENUM('CASH', 'BANK', 'MOBILE_MONEY') NOT NULL,
    `reference` VARCHAR(100) NULL,
    `received_at` DATETIME(3) NOT NULL,
    `status` ENUM('RECEIVED', 'VOIDED') NOT NULL DEFAULT 'RECEIVED',
    `recorded_by_id` BIGINT NOT NULL,
    `idempotency_key` VARCHAR(100) NOT NULL,
    `input_hash` CHAR(64) NOT NULL,
    `voided_at` DATETIME(3) NULL,
    `voided_by_id` BIGINT NULL,
    `void_reason` VARCHAR(500) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `idx_donations_org_status_received`(`org_id`, `status`, `received_at`),
    UNIQUE INDEX `uniq_donations_org_request`(`org_id`, `idempotency_key`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `foundation_events` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `org_id` BIGINT NOT NULL,
    `title` VARCHAR(150) NOT NULL,
    `location` VARCHAR(200) NOT NULL,
    `starts_at` DATETIME(3) NOT NULL,
    `ends_at` DATETIME(3) NOT NULL,
    `cancelled_at` DATETIME(3) NULL,
    `created_by_id` BIGINT NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `idx_events_org_upcoming`(`org_id`, `cancelled_at`, `starts_at`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateIndex
CREATE UNIQUE INDEX `uniq_users_org_id` ON `users`(`org_id`, `id`);

-- AddForeignKey
ALTER TABLE `donors` ADD CONSTRAINT `donors_org_id_fkey` FOREIGN KEY (`org_id`) REFERENCES `organizations`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `fundraising_campaigns` ADD CONSTRAINT `fundraising_campaigns_org_id_fkey` FOREIGN KEY (`org_id`) REFERENCES `organizations`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `donation_pledges` ADD CONSTRAINT `donation_pledges_org_id_fkey` FOREIGN KEY (`org_id`) REFERENCES `organizations`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `donation_pledges` ADD CONSTRAINT `donation_pledges_org_id_donor_id_fkey` FOREIGN KEY (`org_id`, `donor_id`) REFERENCES `donors`(`org_id`, `id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `donation_pledges` ADD CONSTRAINT `donation_pledges_org_id_campaign_id_fkey` FOREIGN KEY (`org_id`, `campaign_id`) REFERENCES `fundraising_campaigns`(`org_id`, `id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `donations` ADD CONSTRAINT `donations_org_id_fkey` FOREIGN KEY (`org_id`) REFERENCES `organizations`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `donations` ADD CONSTRAINT `donations_org_id_donor_id_fkey` FOREIGN KEY (`org_id`, `donor_id`) REFERENCES `donors`(`org_id`, `id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `donations` ADD CONSTRAINT `donations_org_id_campaign_id_fkey` FOREIGN KEY (`org_id`, `campaign_id`) REFERENCES `fundraising_campaigns`(`org_id`, `id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `donations` ADD CONSTRAINT `donations_org_id_pledge_id_fkey` FOREIGN KEY (`org_id`, `pledge_id`) REFERENCES `donation_pledges`(`org_id`, `id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `donations` ADD CONSTRAINT `donations_org_id_recorded_by_id_fkey` FOREIGN KEY (`org_id`, `recorded_by_id`) REFERENCES `users`(`org_id`, `id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `donations` ADD CONSTRAINT `donations_org_id_voided_by_id_fkey` FOREIGN KEY (`org_id`, `voided_by_id`) REFERENCES `users`(`org_id`, `id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `foundation_events` ADD CONSTRAINT `foundation_events_org_id_fkey` FOREIGN KEY (`org_id`) REFERENCES `organizations`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `foundation_events` ADD CONSTRAINT `foundation_events_org_id_created_by_id_fkey` FOREIGN KEY (`org_id`, `created_by_id`) REFERENCES `users`(`org_id`, `id`) ON DELETE RESTRICT ON UPDATE CASCADE;

