ALTER TABLE `course_access_requests`
  ADD COLUMN `office_note` VARCHAR(255) NULL AFTER `request_message`;
