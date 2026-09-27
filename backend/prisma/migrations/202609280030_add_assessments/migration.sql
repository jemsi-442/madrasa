CREATE UNIQUE INDEX uniq_subjects_org_id ON subjects(org_id, id);
CREATE TABLE assessments (
  id BIGINT NOT NULL AUTO_INCREMENT,
  org_id BIGINT NOT NULL, class_id BIGINT NOT NULL, subject_id BIGINT NOT NULL,
  created_by_id BIGINT NOT NULL, client_id CHAR(36) NOT NULL,
  title VARCHAR(150) NOT NULL, assessed_on DATE NOT NULL, max_score INT NOT NULL,
  status ENUM('DRAFT','SUBMITTED','PUBLISHED') NOT NULL DEFAULT 'DRAFT',
  revision INT NOT NULL DEFAULT 1, review_note VARCHAR(500) NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3), updated_at DATETIME(3) NOT NULL,
  PRIMARY KEY(id),
  UNIQUE KEY assessments_org_id_id_key(org_id,id),
  UNIQUE KEY assessments_org_id_created_by_id_client_id_key(org_id,created_by_id,client_id),
  KEY assessments_org_id_class_id_assessed_on_idx(org_id,class_id,assessed_on),
  KEY assessments_org_id_status_assessed_on_idx(org_id,status,assessed_on),
  CONSTRAINT assessments_class_fk FOREIGN KEY(org_id,class_id) REFERENCES classes(org_id,id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT assessments_subject_fk FOREIGN KEY(org_id,subject_id) REFERENCES subjects(org_id,id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT assessments_creator_fk FOREIGN KEY(org_id,created_by_id) REFERENCES users(org_id,id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT assessments_score_limit CHECK(max_score BETWEEN 1 AND 1000),
  CONSTRAINT assessments_revision_positive CHECK(revision > 0)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE TABLE assessment_results (
  id BIGINT NOT NULL AUTO_INCREMENT, org_id BIGINT NOT NULL,
  assessment_id BIGINT NOT NULL, student_id BIGINT NOT NULL,
  score INT NULL, feedback VARCHAR(500) NOT NULL DEFAULT '',
  PRIMARY KEY(id),
  UNIQUE KEY assessment_results_assessment_id_student_id_key(assessment_id,student_id),
  KEY assessment_results_org_id_student_id_idx(org_id,student_id),
  CONSTRAINT assessment_results_assessment_fk FOREIGN KEY(org_id,assessment_id) REFERENCES assessments(org_id,id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT assessment_results_student_fk FOREIGN KEY(org_id,student_id) REFERENCES students(org_id,id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT assessment_results_score_nonnegative CHECK(score IS NULL OR score BETWEEN 0 AND 1000)
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE TABLE assessment_releases (
  id BIGINT NOT NULL AUTO_INCREMENT, org_id BIGINT NOT NULL, assessment_id BIGINT NOT NULL,
  revision INT NOT NULL, published_by_id BIGINT NOT NULL, snapshot JSON NOT NULL,
  created_at DATETIME(3) NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  retracted_at DATETIME(3) NULL, retraction_reason VARCHAR(500) NULL,
  PRIMARY KEY(id),
  UNIQUE KEY assessment_releases_assessment_id_revision_key(assessment_id,revision),
  KEY assessment_releases_org_id_assessment_id_idx(org_id,assessment_id),
  CONSTRAINT assessment_releases_assessment_fk FOREIGN KEY(org_id,assessment_id) REFERENCES assessments(org_id,id) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT assessment_releases_publisher_fk FOREIGN KEY(org_id,published_by_id) REFERENCES users(org_id,id) ON DELETE RESTRICT ON UPDATE CASCADE
) DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
