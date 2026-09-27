CREATE TABLE `family_conversations` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `org_id` BIGINT NOT NULL,
  `student_id` BIGINT NOT NULL,
  `parent_id` BIGINT NOT NULL,
  `teacher_id` BIGINT NOT NULL,
  `parent_read_through` BIGINT NOT NULL DEFAULT 0,
  `teacher_read_through` BIGINT NOT NULL DEFAULT 0,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  `updated_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE INDEX `uniq_family_conversation_org_id` (`org_id`, `id`),
  UNIQUE INDEX `uniq_family_conversation_members` (`org_id`, `student_id`, `parent_id`, `teacher_id`),
  INDEX `idx_family_parent_inbox` (`org_id`, `parent_id`, `updated_at`),
  INDEX `idx_family_teacher_inbox` (`org_id`, `teacher_id`, `updated_at`),
  CONSTRAINT `fk_family_student` FOREIGN KEY (`org_id`, `student_id`) REFERENCES `students` (`org_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_family_parent` FOREIGN KEY (`org_id`, `parent_id`) REFERENCES `users` (`org_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_family_teacher` FOREIGN KEY (`org_id`, `teacher_id`) REFERENCES `users` (`org_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `chk_family_members` CHECK (`parent_id` <> `teacher_id`),
  CONSTRAINT `chk_family_read_cursors` CHECK (`parent_read_through` >= 0 AND `teacher_read_through` >= 0)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE `family_messages` (
  `id` BIGINT NOT NULL AUTO_INCREMENT,
  `org_id` BIGINT NOT NULL,
  `conversation_id` BIGINT NOT NULL,
  `sender_id` BIGINT NOT NULL,
  `client_id` CHAR(36) NOT NULL,
  `body` VARCHAR(2000) NOT NULL,
  `created_at` DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  PRIMARY KEY (`id`),
  UNIQUE INDEX `uniq_family_message_request` (`org_id`, `sender_id`, `client_id`),
  INDEX `idx_family_message_history` (`org_id`, `conversation_id`, `id`),
  CONSTRAINT `fk_family_message_conversation` FOREIGN KEY (`org_id`, `conversation_id`) REFERENCES `family_conversations` (`org_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `fk_family_message_sender` FOREIGN KEY (`org_id`, `sender_id`) REFERENCES `users` (`org_id`, `id`) ON DELETE RESTRICT ON UPDATE RESTRICT,
  CONSTRAINT `chk_family_message_body` CHECK (CHAR_LENGTH(TRIM(`body`)) > 0)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
