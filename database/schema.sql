-- ========================================
-- S-FRAME 데이터베이스 스키마
-- PostgreSQL 14+
-- ========================================

-- 기존 테이블 삭제 (재실행 시)
DROP TABLE IF EXISTS safety_violations CASCADE;
DROP TABLE IF EXISTS proposals CASCADE;
DROP TABLE IF EXISTS employee_awards CASCADE;
DROP TABLE IF EXISTS awards CASCADE;
DROP TABLE IF EXISTS final_grades CASCADE;
DROP TABLE IF EXISTS evaluations CASCADE;
DROP TABLE IF EXISTS employees CASCADE;
DROP TABLE IF EXISTS sites CASCADE;
DROP TABLE IF EXISTS departments CASCADE;

-- ========================================
-- 1. 부서 테이블
-- ========================================
CREATE TABLE departments (
    dept_id SERIAL PRIMARY KEY,
    dept_name VARCHAR(100) NOT NULL,
    dept_type VARCHAR(50) NOT NULL CHECK (dept_type IN ('본사_지원', '본사_기술', '현장', '미래전략TF')),
    parent_dept_id INTEGER REFERENCES departments(dept_id),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ========================================
-- 2. 현장 테이블
-- ========================================
CREATE TABLE sites (
    site_id SERIAL PRIMARY KEY,
    site_name VARCHAR(100) NOT NULL,
    location VARCHAR(200),
    site_manager_id INTEGER,
    progress_rate DECIMAL(5,2) DEFAULT 0,
    safety_score DECIMAL(5,2) DEFAULT 0,
    employee_count INTEGER DEFAULT 0,
    status VARCHAR(50) DEFAULT '진행중',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ========================================
-- 3. 직원 테이블
-- ========================================
CREATE TABLE employees (
    emp_id VARCHAR(50) PRIMARY KEY,
    emp_name VARCHAR(100) NOT NULL,
    password_hash VARCHAR(255),
    dept_id INTEGER REFERENCES departments(dept_id),
    site_id INTEGER REFERENCES sites(site_id),
    role_level VARCHAR(50) NOT NULL CHECK (role_level IN ('팀원', '팀장', '팀장/소장', '부서장', '임원', '대표이사')),
    
    -- Anti-Bias 데이터 (해시처리)
    school_hash VARCHAR(100),
    region_hash VARCHAR(100),
    
    -- KPI 및 평가 데이터
    kpi_score DECIMAL(5,2) DEFAULT 0,
    safety_violations INTEGER DEFAULT 0,
    contribution_score DECIMAL(5,2) DEFAULT 0,
    
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ========================================
-- 4. 평가 테이블 (다면평가)
-- ========================================
CREATE TABLE evaluations (
    eval_id SERIAL PRIMARY KEY,
    evaluated_emp_id VARCHAR(50) REFERENCES employees(emp_id),
    evaluator_emp_id VARCHAR(50) REFERENCES employees(emp_id),
    evaluator_role VARCHAR(50) NOT NULL,
    
    eval_year INTEGER NOT NULL,
    eval_period VARCHAR(20) NOT NULL CHECK (eval_period IN ('상반기', '하반기')),
    
    -- 평가 점수 (가중치 적용 전)
    kpi_score DECIMAL(5,2),
    competency_score DECIMAL(5,2),
    sincerity_score DECIMAL(5,2),
    contribution_score DECIMAL(5,2),
    
    -- 가중치 적용 총점
    total_score DECIMAL(5,2),
    
    -- "다시 함께 일하고 싶은가?"
    work_again BOOLEAN DEFAULT false,
    
    comments TEXT,
    eval_date DATE DEFAULT CURRENT_DATE,
    
    -- 중복 방지
    UNIQUE(evaluated_emp_id, evaluator_emp_id, eval_year, eval_period)
);

-- ========================================
-- 5. 포상 테이블
-- ========================================
CREATE TABLE awards (
    award_id SERIAL PRIMARY KEY,
    award_type VARCHAR(50) NOT NULL CHECK (award_type IN ('최우수직원', '최우수현장', '제안왕')),
    award_year INTEGER NOT NULL,
    award_quarter VARCHAR(20),
    
    -- 개인 포상
    emp_id VARCHAR(50) REFERENCES employees(emp_id),
    
    -- 현장 포상
    site_id INTEGER REFERENCES sites(site_id),
    
    bonus_points DECIMAL(5,2) NOT NULL,
    description TEXT,
    awarded_date DATE DEFAULT CURRENT_DATE
);

-- ========================================
-- 6. 직원-포상 연결 테이블
-- ========================================
CREATE TABLE employee_awards (
    id SERIAL PRIMARY KEY,
    emp_id VARCHAR(50) REFERENCES employees(emp_id),
    award_id INTEGER REFERENCES awards(award_id),
    UNIQUE(emp_id, award_id)
);

-- ========================================
-- 7. 최종 등급 테이블
-- ========================================
CREATE TABLE final_grades (
    grade_id SERIAL PRIMARY KEY,
    emp_id VARCHAR(50) REFERENCES employees(emp_id),
    eval_year INTEGER NOT NULL,
    eval_period VARCHAR(20) NOT NULL,
    
    -- 점수 세부 내역
    base_score DECIMAL(5,2) NOT NULL,
    bonus_score DECIMAL(5,2) DEFAULT 0,
    penalty_score DECIMAL(5,2) DEFAULT 0,
    final_score DECIMAL(5,2) NOT NULL,
    
    -- 최종 등급
    final_grade VARCHAR(5) NOT NULL CHECK (final_grade IN ('S+', 'S', 'A', 'B', 'C', 'F')),
    
    -- CEO 특별 점수
    ceo_special_point DECIMAL(5,2) DEFAULT 0,
    
    -- 승인
    is_approved BOOLEAN DEFAULT false,
    approved_by VARCHAR(50) REFERENCES employees(emp_id),
    approved_date DATE,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(emp_id, eval_year, eval_period)
);

-- ========================================
-- 8. 안전 위반 테이블
-- ========================================
CREATE TABLE safety_violations (
    violation_id SERIAL PRIMARY KEY,
    emp_id VARCHAR(50) REFERENCES employees(emp_id),
    site_id INTEGER REFERENCES sites(site_id),
    
    violation_type VARCHAR(100) NOT NULL,
    severity VARCHAR(50) CHECK (severity IN ('경미', '중대', '매우중대')),
    violation_date DATE NOT NULL,
    description TEXT,
    
    -- 조치사항
    action_taken TEXT,
    is_resolved BOOLEAN DEFAULT false,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ========================================
-- 9. 제안 시스템 테이블
-- ========================================
CREATE TABLE proposals (
    proposal_id SERIAL PRIMARY KEY,
    emp_id VARCHAR(50) REFERENCES employees(emp_id),
    
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    category VARCHAR(50),
    
    proposal_date DATE DEFAULT CURRENT_DATE,
    status VARCHAR(50) DEFAULT '제출' CHECK (status IN ('제출', '검토중', '채택', '보류', '반려')),
    
    -- 심사
    reviewer_id VARCHAR(50) REFERENCES employees(emp_id),
    review_date DATE,
    review_comments TEXT,
    
    -- 채택 시 보상
    reward_points DECIMAL(5,2) DEFAULT 0,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ========================================
-- 10. 인덱스 생성 (성능 최적화)
-- ========================================
CREATE INDEX idx_employees_dept ON employees(dept_id);
CREATE INDEX idx_employees_site ON employees(site_id);
CREATE INDEX idx_evaluations_evaluated ON evaluations(evaluated_emp_id);
CREATE INDEX idx_evaluations_year_period ON evaluations(eval_year, eval_period);
CREATE INDEX idx_safety_violations_emp ON safety_violations(emp_id);
CREATE INDEX idx_proposals_emp ON proposals(emp_id);
CREATE INDEX idx_proposals_status ON proposals(status);

-- ========================================
-- 11. 샘플 데이터 삽입
-- ========================================

-- 부서
INSERT INTO departments (dept_name, dept_type) VALUES
('경영지원실', '본사_지원'),
('기술지원본부', '본사_기술'),
('원가관리실', '본사_지원'),
('안전보건경영실', '본사_기술'),
('재무관리실', '본사_지원'),
('구매관리실', '본사_지원'),
('미래전략TF팀', '미래전략TF');

-- 현장 (25개)
INSERT INTO sites (site_name, location, progress_rate, safety_score, employee_count) VALUES
('1번 현장', '서울 강남구', 85.5, 92.0, 15),
('2번 현장', '서울 서초구', 72.3, 88.5, 12),
('3번 현장', '경기 성남시', 95.2, 91.0, 18),
('4번 현장', '경기 용인시', 68.7, 85.0, 14),
('5번 현장', '인천 연수구', 88.9, 93.5, 16),
('6번 현장', '부산 해운대구', 91.2, 89.0, 20),
('7번 현장', '대구 수성구', 98.5, 96.0, 25),
('8번 현장', '광주 서구', 77.8, 90.0, 13),
('9번 현장', '대전 유성구', 82.4, 87.5, 17),
('10번 현장', '울산 남구', 90.1, 94.0, 19);

-- 추가 15개 현장
INSERT INTO sites (site_name, location, progress_rate, safety_score, employee_count) 
SELECT 
    (10 + n) || '번 현장',
    CASE (n % 5)
        WHEN 0 THEN '경기 화성시'
        WHEN 1 THEN '경기 평택시'
        WHEN 2 THEN '충북 청주시'
        WHEN 3 THEN '충남 천안시'
        ELSE '전북 전주시'
    END,
    70 + (n * 3.5),
    85 + (n * 1.2),
    10 + n
FROM generate_series(1, 15) AS n;

-- 직원
INSERT INTO employees (emp_id, emp_name, dept_id, site_id, role_level, kpi_score) VALUES
('E001', '홍길동', 1, NULL, '대표이사', 95.0),
('E002', '김현장', NULL, 7, '팀장/소장', 88.0),
('E003', '박본부', 2, NULL, '부서장', 92.0),
('E004', '이소장', NULL, 12, '팀장/소장', 85.0),
('E005', '최팀장', 1, NULL, '팀장', 90.0),
('E006', '정부장', 5, NULL, '부서장', 87.0),
('E007', '강팀원', NULL, 7, '팀원', 82.0);

-- 평가 (샘플)
INSERT INTO evaluations (evaluated_emp_id, evaluator_emp_id, evaluator_role, eval_year, eval_period, kpi_score, competency_score, sincerity_score, contribution_score, total_score) VALUES
('E002', 'E001', '대표이사', 2025, '상반기', 88, 26, 18, 8, 85.6),
('E003', 'E001', '대표이사', 2025, '상반기', 92, 28, 19, 9, 89.2);

-- 포상
INSERT INTO awards (award_type, award_year, site_id, bonus_points, description) VALUES
('최우수현장', 2025, 7, 3.0, '안전점수 96점 달성');

INSERT INTO awards (award_type, award_year, emp_id, bonus_points, description) VALUES
('최우수직원', 2025, 'E004', 10.0, '뛰어난 현장 관리');

-- 안전 위반 (예시)
INSERT INTO safety_violations (emp_id, site_id, violation_type, severity, violation_date, description) VALUES
('E007', 7, '안전모 미착용', '경미', '2025-01-15', '현장 순찰 중 발견');

-- ========================================
-- 12. 뷰 생성 (편리한 조회)
-- ========================================

-- 직원 평가 요약 뷰
CREATE OR REPLACE VIEW v_employee_evaluation_summary AS
SELECT 
    e.emp_id,
    e.emp_name,
    d.dept_name,
    s.site_name,
    e.role_level,
    e.kpi_score,
    e.safety_violations,
    COUNT(DISTINCT ev.eval_id) as evaluation_count,
    AVG(ev.total_score) as avg_evaluation_score,
    COUNT(DISTINCT a.award_id) as award_count,
    COALESCE(SUM(aw.bonus_points), 0) as total_bonus_points
FROM employees e
LEFT JOIN departments d ON e.dept_id = d.dept_id
LEFT JOIN sites s ON e.site_id = s.site_id
LEFT JOIN evaluations ev ON e.emp_id = ev.evaluated_emp_id
LEFT JOIN employee_awards ea ON e.emp_id = ea.emp_id
LEFT JOIN awards a ON ea.award_id = a.award_id
LEFT JOIN awards aw ON ea.award_id = aw.award_id
WHERE e.is_active = true
GROUP BY e.emp_id, e.emp_name, d.dept_name, s.site_name, e.role_level, e.kpi_score, e.safety_violations;

-- 현장 통계 뷰
CREATE OR REPLACE VIEW v_site_statistics AS
SELECT 
    s.site_id,
    s.site_name,
    s.location,
    s.progress_rate,
    s.safety_score,
    s.employee_count,
    COUNT(DISTINCT sv.violation_id) as total_violations,
    AVG(e.kpi_score) as avg_employee_kpi
FROM sites s
LEFT JOIN employees e ON s.site_id = e.site_id AND e.is_active = true
LEFT JOIN safety_violations sv ON s.site_id = sv.site_id
GROUP BY s.site_id, s.site_name, s.location, s.progress_rate, s.safety_score, s.employee_count;

-- ========================================
-- 완료!
-- ========================================
-- 데이터베이스 스키마 생성 완료
-- 샘플 데이터 삽입 완료
-- 인덱스 및 뷰 생성 완료
