-- CreateTable
CREATE TABLE `curriculum_lesson_deliveries` (
    `id` VARCHAR(30) NOT NULL,
    `orgId` BIGINT NOT NULL,
    `classCurriculumId` VARCHAR(30) NOT NULL,
    `assignmentId` VARCHAR(30) NOT NULL,
    `lessonId` VARCHAR(30) NOT NULL,
    `teacherId` BIGINT NOT NULL,
    `clientEventId` VARCHAR(36) NOT NULL,
    `taughtAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `curriculum_lesson_deliveries_orgId_classCurriculumId_taughtA_idx`(`orgId`, `classCurriculumId`, `taughtAt`),
    UNIQUE INDEX `curriculum_lesson_deliveries_orgId_teacherId_clientEventId_key`(`orgId`, `teacherId`, `clientEventId`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateIndex
CREATE UNIQUE INDEX `class_curricula_orgId_id_key` ON `class_curricula`(`orgId`, `id`);

-- AddForeignKey
ALTER TABLE `curriculum_lesson_deliveries` ADD CONSTRAINT `curriculum_lesson_deliveries_orgId_classCurriculumId_fkey` FOREIGN KEY (`orgId`, `classCurriculumId`) REFERENCES `class_curricula`(`orgId`, `id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `curriculum_lesson_deliveries` ADD CONSTRAINT `curriculum_lesson_deliveries_orgId_assignmentId_fkey` FOREIGN KEY (`orgId`, `assignmentId`) REFERENCES `curriculum_assignments`(`organizationId`, `id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `curriculum_lesson_deliveries` ADD CONSTRAINT `curriculum_lesson_deliveries_lessonId_fkey` FOREIGN KEY (`lessonId`) REFERENCES `curriculum_lessons`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE `curriculum_lesson_deliveries` ADD CONSTRAINT `curriculum_lesson_deliveries_teacherId_fkey` FOREIGN KEY (`teacherId`) REFERENCES `users`(`id`) ON DELETE RESTRICT ON UPDATE CASCADE;

