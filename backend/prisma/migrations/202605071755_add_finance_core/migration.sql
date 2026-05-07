CREATE TABLE `fee_structures` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `org_id` BIGINT NOT NULL,
  `branch_id` BIGINT NULL,
  `class_id` BIGINT NULL,
  `name` VARCHAR(150) NOT NULL,
  `amount` DECIMAL(12,2) NOT NULL,
  `billing_cycle` ENUM('ONE_TIME', 'MONTHLY', 'TERMLY') NOT NULL,
  `is_active` BOOLEAN NOT NULL DEFAULT true,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  INDEX `idx_fee_structures_org_branch_class` (`org_id`, `branch_id`, `class_id`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `invoices` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `org_id` BIGINT NOT NULL,
  `branch_id` BIGINT NOT NULL,
  `student_id` BIGINT NOT NULL,
  `fee_structure_id` BIGINT NULL,
  `invoice_no` VARCHAR(50) NOT NULL,
  `amount_due` DECIMAL(12,2) NOT NULL,
  `amount_paid` DECIMAL(12,2) NOT NULL DEFAULT 0.00,
  `currency` CHAR(3) NOT NULL DEFAULT 'TZS',
  `due_date` DATE NOT NULL,
  `status` ENUM('PENDING', 'PARTIALLY_PAID', 'PAID', 'OVERDUE', 'CANCELLED') NOT NULL DEFAULT 'PENDING',
  `issued_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  UNIQUE INDEX `uniq_invoices_org_invoice_no` (`org_id`, `invoice_no`),
  INDEX `idx_invoices_org_student_status` (`org_id`, `student_id`, `status`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `expenses` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `org_id` BIGINT NOT NULL,
  `branch_id` BIGINT NULL,
  `title` VARCHAR(150) NOT NULL,
  `description` TEXT NULL,
  `amount` DECIMAL(12,2) NOT NULL,
  `currency` CHAR(3) NOT NULL DEFAULT 'TZS',
  `expense_date` DATE NOT NULL,
  `recorded_by_id` BIGINT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  INDEX `idx_expenses_org_branch_expense_date` (`org_id`, `branch_id`, `expense_date`),
  PRIMARY KEY (`id`)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

ALTER TABLE `fee_structures`
  ADD CONSTRAINT `fee_structures_org_id_fkey`
  FOREIGN KEY (`org_id`) REFERENCES `organizations`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `fee_structures`
  ADD CONSTRAINT `fee_structures_branch_id_fkey`
  FOREIGN KEY (`branch_id`) REFERENCES `branches`(`id`)
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE `fee_structures`
  ADD CONSTRAINT `fee_structures_class_id_fkey`
  FOREIGN KEY (`class_id`) REFERENCES `classes`(`id`)
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE `invoices`
  ADD CONSTRAINT `invoices_org_id_fkey`
  FOREIGN KEY (`org_id`) REFERENCES `organizations`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `invoices`
  ADD CONSTRAINT `invoices_branch_id_fkey`
  FOREIGN KEY (`branch_id`) REFERENCES `branches`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `invoices`
  ADD CONSTRAINT `invoices_student_id_fkey`
  FOREIGN KEY (`student_id`) REFERENCES `students`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `invoices`
  ADD CONSTRAINT `invoices_fee_structure_id_fkey`
  FOREIGN KEY (`fee_structure_id`) REFERENCES `fee_structures`(`id`)
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE `expenses`
  ADD CONSTRAINT `expenses_org_id_fkey`
  FOREIGN KEY (`org_id`) REFERENCES `organizations`(`id`)
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE `expenses`
  ADD CONSTRAINT `expenses_branch_id_fkey`
  FOREIGN KEY (`branch_id`) REFERENCES `branches`(`id`)
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE `expenses`
  ADD CONSTRAINT `expenses_recorded_by_id_fkey`
  FOREIGN KEY (`recorded_by_id`) REFERENCES `users`(`id`)
  ON DELETE SET NULL ON UPDATE CASCADE;

