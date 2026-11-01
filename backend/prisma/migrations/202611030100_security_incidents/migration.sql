CREATE TABLE `security_incidents` (
  `id` VARCHAR(30) NOT NULL, `title` VARCHAR(160) NOT NULL,
  `description` TEXT NOT NULL, `priority` VARCHAR(10) NOT NULL,
  `status` VARCHAR(20) NOT NULL DEFAULT 'OPEN', `ownerId` VARCHAR(30) NOT NULL,
  `revision` INTEGER NOT NULL DEFAULT 1,
  `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updatedAt` DATETIME(3) NOT NULL, `resolvedAt` DATETIME(3) NULL,
  PRIMARY KEY (`id`), INDEX `security_incidents_createdAt_id_idx` (`createdAt`, `id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE TABLE `security_incident_entries` (
  `id` VARCHAR(30) NOT NULL, `incidentId` VARCHAR(30) NOT NULL,
  `actorId` VARCHAR(30) NOT NULL, `status` VARCHAR(20) NOT NULL,
  `note` TEXT NOT NULL, `createdAt` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`), INDEX `security_incident_entries_incidentId_createdAt_idx` (`incidentId`, `createdAt`),
  CONSTRAINT `security_incident_entries_incidentId_fkey` FOREIGN KEY (`incidentId`) REFERENCES `security_incidents` (`id`) ON DELETE RESTRICT ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
