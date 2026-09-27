-- CreateTable
CREATE TABLE `reporting_periods` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `org_id` BIGINT NOT NULL,
    `created_by_id` BIGINT NOT NULL,
    `client_id` CHAR(36) NOT NULL,
    `name` VARCHAR(150) NOT NULL,
    `starts_on` DATE NOT NULL,
    `ends_on` DATE NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `reporting_periods_org_id_starts_on_idx`(`org_id`, `starts_on`),
    UNIQUE INDEX `reporting_periods_org_id_id_key`(`org_id`, `id`),
    UNIQUE INDEX `reporting_periods_org_id_client_id_key`(`org_id`, `client_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `student_reports` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `org_id` BIGINT NOT NULL,
    `period_id` BIGINT NOT NULL,
    `class_id` BIGINT NOT NULL,
    `student_id` BIGINT NOT NULL,
    `prepared_by_id` BIGINT NOT NULL,
    `feedback` VARCHAR(2000) NOT NULL DEFAULT '',
    `status` ENUM('DRAFT', 'SUBMITTED', 'PUBLISHED') NOT NULL DEFAULT 'DRAFT',
    `revision` INTEGER NOT NULL DEFAULT 1,
    `draft` JSON NOT NULL,
    `review_note` VARCHAR(500) NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `updated_at` DATETIME(3) NOT NULL,

    INDEX `student_reports_org_id_class_id_status_idx`(`org_id`, `class_id`, `status`),
    UNIQUE INDEX `student_reports_org_id_id_key`(`org_id`, `id`),
    UNIQUE INDEX `student_reports_period_id_student_id_key`(`period_id`, `student_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `report_releases` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `org_id` BIGINT NOT NULL,
    `report_id` BIGINT NOT NULL,
    `revision` INTEGER NOT NULL,
    `published_by_id` BIGINT NOT NULL,
    `snapshot` JSON NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `retracted_at` DATETIME(3) NULL,
    `retraction_reason` VARCHAR(500) NULL,

    INDEX `report_releases_org_id_report_id_idx`(`org_id`, `report_id`),
    UNIQUE INDEX `report_releases_org_id_id_key`(`org_id`, `id`),
    UNIQUE INDEX `report_releases_report_id_revision_key`(`report_id`, `revision`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `report_assessment_sources` (
    `org_id` BIGINT NOT NULL,
    `report_release_id` BIGINT NOT NULL,
    `assessment_release_id` BIGINT NOT NULL,

    PRIMARY KEY (`report_release_id`, `assessment_release_id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateIndex
CREATE UNIQUE INDEX `assessment_releases_org_id_id_key` ON `assessment_releases`(`org_id`, `id`);

-- AddForeignKey
ALTER TABLE `reporting_periods` ADD CONSTRAINT `reporting_periods_org_id_created_by_id_fkey` FOREIGN KEY (`org_id`, `created_by_id`) REFERENCES `users`(`org_id`, `id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `student_reports` ADD CONSTRAINT `student_reports_org_id_period_id_fkey` FOREIGN KEY (`org_id`, `period_id`) REFERENCES `reporting_periods`(`org_id`, `id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `student_reports` ADD CONSTRAINT `student_reports_org_id_class_id_fkey` FOREIGN KEY (`org_id`, `class_id`) REFERENCES `classes`(`org_id`, `id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `student_reports` ADD CONSTRAINT `student_reports_org_id_student_id_fkey` FOREIGN KEY (`org_id`, `student_id`) REFERENCES `students`(`org_id`, `id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `student_reports` ADD CONSTRAINT `student_reports_org_id_prepared_by_id_fkey` FOREIGN KEY (`org_id`, `prepared_by_id`) REFERENCES `users`(`org_id`, `id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `report_releases` ADD CONSTRAINT `report_releases_org_id_report_id_fkey` FOREIGN KEY (`org_id`, `report_id`) REFERENCES `student_reports`(`org_id`, `id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `report_releases` ADD CONSTRAINT `report_releases_org_id_published_by_id_fkey` FOREIGN KEY (`org_id`, `published_by_id`) REFERENCES `users`(`org_id`, `id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `report_assessment_sources` ADD CONSTRAINT `report_assessment_sources_org_id_report_release_id_fkey` FOREIGN KEY (`org_id`, `report_release_id`) REFERENCES `report_releases`(`org_id`, `id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `report_assessment_sources` ADD CONSTRAINT `report_assessment_sources_org_id_assessment_release_id_fkey` FOREIGN KEY (`org_id`, `assessment_release_id`) REFERENCES `assessment_releases`(`org_id`, `id`) ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE reporting_periods ADD CONSTRAINT reporting_period_dates CHECK (ends_on >= starts_on);
ALTER TABLE student_reports ADD CONSTRAINT report_revision_positive CHECK (revision > 0);
