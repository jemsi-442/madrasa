-- CreateTable
CREATE TABLE `class_timetable_slots` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `org_id` BIGINT NOT NULL,
    `class_id` BIGINT NOT NULL,
    `weekday` INTEGER NOT NULL,
    `starts_at` CHAR(5) NOT NULL,
    `ends_at` CHAR(5) NOT NULL,
    `valid_from` DATE NOT NULL,
    `valid_until` DATE NOT NULL,
    `subject` VARCHAR(100) NOT NULL,
    `focus` VARCHAR(255) NULL,
    `room` VARCHAR(100) NULL,
    `cancelled_at` DATETIME(3) NULL,
    `created_by_id` BIGINT NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),

    INDEX `idx_timetable_class_day`(`org_id`, `class_id`, `cancelled_at`, `weekday`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `quran_sessions` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `org_id` BIGINT NOT NULL,
    `class_id` BIGINT NOT NULL,
    `student_id` BIGINT NOT NULL,
    `teacher_id` BIGINT NOT NULL,
    `client_id` CHAR(36) NOT NULL,
    `request_hash` CHAR(64) NOT NULL,
    `surah_id` INTEGER NOT NULL,
    `ayah_from` INTEGER NOT NULL,
    `ayah_to` INTEGER NOT NULL,
    `activity` ENUM('READING', 'MEMORIZATION', 'REVISION', 'TAJWEED') NOT NULL,
    `observation` ENUM('INDEPENDENT', 'WITH_SUPPORT', 'NEEDS_PRACTICE') NOT NULL,
    `note` VARCHAR(1000) NULL,
    `learned_on` DATE NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `voided_at` DATETIME(3) NULL,
    `void_reason` VARCHAR(255) NULL,

    INDEX `idx_quran_student_surah`(`org_id`, `student_id`, `surah_id`, `learned_on`),
    INDEX `idx_quran_class_created`(`org_id`, `class_id`, `created_at`),
    UNIQUE INDEX `uniq_quran_request`(`org_id`, `teacher_id`, `client_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateTable
CREATE TABLE `student_support_notes` (
    `id` BIGINT NOT NULL AUTO_INCREMENT,
    `org_id` BIGINT NOT NULL,
    `student_id` BIGINT NOT NULL,
    `class_id` BIGINT NOT NULL,
    `created_by_id` BIGINT NOT NULL,
    `client_id` CHAR(36) NOT NULL,
    `note` VARCHAR(500) NOT NULL,
    `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
    `resolved_at` DATETIME(3) NULL,
    `resolved_by_id` BIGINT NULL,

    INDEX `idx_support_student`(`org_id`, `student_id`, `resolved_at`),
    UNIQUE INDEX `uniq_support_request`(`org_id`, `created_by_id`, `client_id`),
    PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- CreateIndex
CREATE UNIQUE INDEX `uniq_classes_org_id` ON `classes`(`org_id`, `id`);

-- CreateIndex
CREATE UNIQUE INDEX `uniq_students_org_id` ON `students`(`org_id`, `id`);

-- AddForeignKey
ALTER TABLE `class_timetable_slots` ADD CONSTRAINT `class_timetable_slots_org_id_class_id_fkey` FOREIGN KEY (`org_id`, `class_id`) REFERENCES `classes`(`org_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE `class_timetable_slots` ADD CONSTRAINT `class_timetable_slots_org_id_created_by_id_fkey` FOREIGN KEY (`org_id`, `created_by_id`) REFERENCES `users`(`org_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE `quran_sessions` ADD CONSTRAINT `quran_sessions_org_id_class_id_fkey` FOREIGN KEY (`org_id`, `class_id`) REFERENCES `classes`(`org_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE `quran_sessions` ADD CONSTRAINT `quran_sessions_org_id_student_id_fkey` FOREIGN KEY (`org_id`, `student_id`) REFERENCES `students`(`org_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE `quran_sessions` ADD CONSTRAINT `quran_sessions_org_id_teacher_id_fkey` FOREIGN KEY (`org_id`, `teacher_id`) REFERENCES `users`(`org_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE `student_support_notes` ADD CONSTRAINT `student_support_notes_org_id_class_id_fkey` FOREIGN KEY (`org_id`, `class_id`) REFERENCES `classes`(`org_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE `student_support_notes` ADD CONSTRAINT `student_support_notes_org_id_student_id_fkey` FOREIGN KEY (`org_id`, `student_id`) REFERENCES `students`(`org_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE `student_support_notes` ADD CONSTRAINT `student_support_notes_org_id_created_by_id_fkey` FOREIGN KEY (`org_id`, `created_by_id`) REFERENCES `users`(`org_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;

-- AddForeignKey
ALTER TABLE `student_support_notes` ADD CONSTRAINT `student_support_notes_org_id_resolved_by_id_fkey` FOREIGN KEY (`org_id`, `resolved_by_id`) REFERENCES `users`(`org_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT;

ALTER TABLE class_timetable_slots
  ADD CONSTRAINT chk_timetable_weekday CHECK (weekday BETWEEN 1 AND 7),
  ADD CONSTRAINT chk_timetable_times CHECK (starts_at REGEXP '^([01][0-9]|2[0-3]):[0-5][0-9]$' AND ends_at REGEXP '^([01][0-9]|2[0-3]):[0-5][0-9]$' AND starts_at < ends_at),
  ADD CONSTRAINT chk_timetable_period CHECK (valid_from <= valid_until);
ALTER TABLE quran_sessions
  ADD CONSTRAINT chk_quran_passage CHECK (surah_id BETWEEN 1 AND 114 AND ayah_from >= 1 AND ayah_to >= ayah_from AND ayah_to <= 286);

