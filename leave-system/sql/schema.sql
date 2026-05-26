-- ============================================================
-- 学生请假事务管理系统 - 数据库建表脚本
-- 数据库: MySQL 8.0
-- 作者: 汤俊豪
-- ============================================================

CREATE DATABASE IF NOT EXISTS leave_system
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE leave_system;

-- ============================================================
-- 1. 班级表 (Class)
-- ============================================================
CREATE TABLE Class (
    class_id   VARCHAR(20)  PRIMARY KEY     COMMENT '班级编号',
    class_name VARCHAR(100) NOT NULL        COMMENT '班级名称',
    department VARCHAR(100) NOT NULL        COMMENT '所属院系',
    grade      VARCHAR(10)  NOT NULL        COMMENT '年级'
) ENGINE=InnoDB COMMENT='班级表';

-- ============================================================
-- 2. 学生表 (Student)
-- ============================================================
CREATE TABLE Student (
    student_id VARCHAR(20)  PRIMARY KEY     COMMENT '学号',
    name       VARCHAR(50)  NOT NULL        COMMENT '姓名',
    gender     CHAR(2)      NOT NULL        COMMENT '性别',
    password   VARCHAR(100) NOT NULL DEFAULT '123456' COMMENT '登录密码',
    phone      VARCHAR(20)  DEFAULT NULL    COMMENT '联系电话',
    email      VARCHAR(100) DEFAULT NULL    COMMENT '电子邮箱',
    class_id   VARCHAR(20)  NOT NULL        COMMENT '班级编号',
    CONSTRAINT fk_student_class FOREIGN KEY (class_id) REFERENCES Class(class_id),
    CONSTRAINT chk_student_gender CHECK (gender IN ('男', '女'))
) ENGINE=InnoDB COMMENT='学生表';

CREATE INDEX idx_student_class_id ON Student(class_id);

-- ============================================================
-- 3. 班主任表 (Teacher)
-- ============================================================
CREATE TABLE Teacher (
    teacher_id VARCHAR(20)  PRIMARY KEY     COMMENT '教师编号',
    name       VARCHAR(50)  NOT NULL        COMMENT '姓名',
    gender     CHAR(2)      NOT NULL        COMMENT '性别',
    password   VARCHAR(100) NOT NULL DEFAULT '123456' COMMENT '登录密码',
    phone      VARCHAR(20)  DEFAULT NULL    COMMENT '联系电话',
    email      VARCHAR(100) DEFAULT NULL    COMMENT '电子邮箱',
    class_id   VARCHAR(20)  DEFAULT NULL    COMMENT '管辖班级编号',
    CONSTRAINT fk_teacher_class FOREIGN KEY (class_id) REFERENCES Class(class_id),
    CONSTRAINT uk_teacher_class UNIQUE (class_id),
    CONSTRAINT chk_teacher_gender CHECK (gender IN ('男', '女'))
) ENGINE=InnoDB COMMENT='班主任表';

CREATE UNIQUE INDEX idx_teacher_class_id ON Teacher(class_id);

-- ============================================================
-- 4. 教务管理员表 (Admin)
-- ============================================================
CREATE TABLE Admin (
    admin_id VARCHAR(20)  PRIMARY KEY     COMMENT '管理员编号',
    name     VARCHAR(50)  NOT NULL        COMMENT '姓名',
    password VARCHAR(100) NOT NULL DEFAULT '123456' COMMENT '登录密码',
    phone    VARCHAR(20)  DEFAULT NULL    COMMENT '联系电话',
    email    VARCHAR(100) DEFAULT NULL    COMMENT '电子邮箱'
) ENGINE=InnoDB COMMENT='教务管理员表';

-- ============================================================
-- 5. 请假记录表 (LeaveRecord)
-- ============================================================
CREATE TABLE LeaveRecord (
    leave_id        INT          AUTO_INCREMENT PRIMARY KEY COMMENT '请假编号',
    student_id      VARCHAR(20)  NOT NULL        COMMENT '学生编号',
    leave_type      VARCHAR(20)  NOT NULL        COMMENT '请假类型(事假/病假/公假/其他)',
    start_date      DATE         NOT NULL        COMMENT '开始日期',
    end_date        DATE         NOT NULL        COMMENT '结束日期',
    reason          TEXT         NOT NULL        COMMENT '请假原因',
    status          ENUM('待审批','已批准','已驳回') NOT NULL DEFAULT '待审批' COMMENT '审批状态',
    apply_time      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP COMMENT '申请时间',
    teacher_id      VARCHAR(20)  DEFAULT NULL    COMMENT '审批教师编号',
    approve_time    DATETIME     DEFAULT NULL    COMMENT '审批时间',
    approve_comment TEXT         DEFAULT NULL    COMMENT '审批意见',
    CONSTRAINT fk_leave_student  FOREIGN KEY (student_id) REFERENCES Student(student_id),
    CONSTRAINT fk_leave_teacher  FOREIGN KEY (teacher_id) REFERENCES Teacher(teacher_id),
    CONSTRAINT chk_leave_date   CHECK (end_date >= start_date)
) ENGINE=InnoDB COMMENT='请假记录表';

CREATE INDEX idx_leave_student_id ON LeaveRecord(student_id);
CREATE INDEX idx_leave_status     ON LeaveRecord(status);
CREATE INDEX idx_leave_apply_time ON LeaveRecord(apply_time);
CREATE INDEX idx_leave_teacher_id ON LeaveRecord(teacher_id);
CREATE INDEX idx_leave_date_range ON LeaveRecord(start_date, end_date);

-- ============================================================
-- 视图 1: 学生请假详情视图
-- ============================================================
CREATE VIEW v_student_leave_detail AS
SELECT
    lr.leave_id,
    lr.student_id,
    s.name        AS student_name,
    s.gender,
    c.class_id,
    c.class_name,
    c.department,
    lr.leave_type,
    lr.start_date,
    lr.end_date,
    DATEDIFF(lr.end_date, lr.start_date) + 1 AS leave_days,
    lr.reason,
    lr.status,
    lr.apply_time,
    lr.teacher_id,
    lr.approve_time,
    lr.approve_comment
FROM LeaveRecord lr
JOIN Student s  ON lr.student_id = s.student_id
JOIN Class c    ON s.class_id = c.class_id;

-- ============================================================
-- 视图 2: 待审批请假视图
-- ============================================================
CREATE VIEW v_pending_leave AS
SELECT
    lr.leave_id,
    lr.student_id,
    s.name        AS student_name,
    c.class_name,
    lr.leave_type,
    lr.start_date,
    lr.end_date,
    DATEDIFF(lr.end_date, lr.start_date) + 1 AS leave_days,
    lr.reason,
    lr.apply_time
FROM LeaveRecord lr
JOIN Student s  ON lr.student_id = s.student_id
JOIN Class c    ON s.class_id = c.class_id
WHERE lr.status = '待审批'
ORDER BY lr.apply_time ASC;

-- ============================================================
-- 视图 3: 班级请假统计视图
-- ============================================================
CREATE VIEW v_class_leave_statistics AS
SELECT
    c.class_id,
    c.class_name,
    c.department,
    c.grade,
    COUNT(lr.leave_id) AS total_leaves,
    SUM(CASE WHEN lr.status = '已批准' THEN 1 ELSE 0 END) AS approved,
    SUM(CASE WHEN lr.status = '已驳回' THEN 1 ELSE 0 END) AS rejected,
    SUM(CASE WHEN lr.status = '待审批' THEN 1 ELSE 0 END) AS pending
FROM Class c
LEFT JOIN Student s   ON c.class_id = s.class_id
LEFT JOIN LeaveRecord lr ON s.student_id = lr.student_id
GROUP BY c.class_id, c.class_name, c.department, c.grade;

-- ============================================================
-- 视图 4: 审批历史视图
-- ============================================================
CREATE VIEW v_approval_history AS
SELECT
    lr.leave_id,
    lr.student_id,
    s.name        AS student_name,
    lr.leave_type,
    lr.status,
    lr.apply_time,
    lr.teacher_id,
    t.name        AS teacher_name,
    lr.approve_time,
    lr.approve_comment
FROM LeaveRecord lr
JOIN Student s  ON lr.student_id = s.student_id
LEFT JOIN Teacher t ON lr.teacher_id = t.teacher_id
WHERE lr.status IN ('已批准', '已驳回')
ORDER BY lr.approve_time DESC;
