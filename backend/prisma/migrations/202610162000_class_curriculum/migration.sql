CREATE UNIQUE INDEX `curriculum_assignments_organizationId_id_key` ON `curriculum_assignments` (`organizationId`, `id`);
CREATE TABLE `class_curricula` (
  `id` VARCHAR(30) NOT NULL PRIMARY KEY,
  `orgId` BIGINT NOT NULL,
  `classId` BIGINT NOT NULL,
  `subjectId` BIGINT NOT NULL,
  `assignmentId` VARCHAR(30) NOT NULL,
  `adoptedBy` BIGINT NOT NULL,
  `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE INDEX `class_curricula_classId_subjectId_key` (`classId`, `subjectId`),
  INDEX `class_curricula_orgId_assignmentId_idx` (`orgId`, `assignmentId`),
  FOREIGN KEY (`orgId`, `classId`) REFERENCES `classes` (`org_id`, `id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  FOREIGN KEY (`orgId`, `subjectId`) REFERENCES `subjects` (`org_id`, `id`) ON DELETE RESTRICT ON UPDATE CASCADE,
  FOREIGN KEY (`orgId`, `assignmentId`) REFERENCES `curriculum_assignments` (`organizationId`, `id`) ON DELETE RESTRICT ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
