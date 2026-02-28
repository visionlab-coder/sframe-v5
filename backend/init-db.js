// ========================================
// S-FRAME Railway 자동 설정 스크립트
// 이 스크립트는 Railway 배포 시 자동으로 실행됩니다
// ========================================

const { Client } = require('pg');

async function initializeDatabase() {
    console.log('🚀 S-FRAME 데이터베이스 초기화 시작...\n');

    // Railway 환경변수에서 자동으로 DATABASE_URL 가져옴
    const client = new Client({
        connectionString: process.env.DATABASE_URL,
        ssl: { rejectUnauthorized: false }
    });

    try {
        await client.connect();
        console.log('✅ 데이터베이스 연결 성공!\n');

        // 테이블 존재 확인
        const checkTables = await client.query(`
            SELECT COUNT(*) 
            FROM information_schema.tables 
            WHERE table_schema = 'public' AND table_name = 'employees'
        `);

        if (parseInt(checkTables.rows[0].count) > 0) {
            console.log('✅ 테이블이 이미 존재합니다. 초기화 스킵.\n');
            await client.end();
            return;
        }

        console.log('⚙️  테이블 생성 중...\n');

        // 간단 버전 스키마 (핵심만)
        await client.query(`
            -- 부서
            CREATE TABLE departments (
                dept_id SERIAL PRIMARY KEY,
                dept_name VARCHAR(100) NOT NULL,
                dept_type VARCHAR(50) NOT NULL
            );

            -- 현장
            CREATE TABLE sites (
                site_id SERIAL PRIMARY KEY,
                site_name VARCHAR(100) NOT NULL,
                location VARCHAR(200),
                safety_score DECIMAL(5,2) DEFAULT 0
            );

            -- 직원
            CREATE TABLE employees (
                emp_id VARCHAR(50) PRIMARY KEY,
                emp_name VARCHAR(100) NOT NULL,
                dept_id INTEGER REFERENCES departments(dept_id),
                site_id INTEGER REFERENCES sites(site_id),
                role_level VARCHAR(50) NOT NULL,
                kpi_score DECIMAL(5,2) DEFAULT 0,
                safety_violations INTEGER DEFAULT 0,
                is_active BOOLEAN DEFAULT true
            );

            -- 평가
            CREATE TABLE evaluations (
                eval_id SERIAL PRIMARY KEY,
                evaluated_emp_id VARCHAR(50) REFERENCES employees(emp_id),
                evaluator_emp_id VARCHAR(50) REFERENCES employees(emp_id),
                evaluator_role VARCHAR(50),
                eval_year INTEGER,
                eval_period VARCHAR(20),
                competency_score DECIMAL(5,2),
                sincerity_score DECIMAL(5,2),
                total_score DECIMAL(5,2)
            );

            -- 안전 위반
            CREATE TABLE safety_violations (
                violation_id SERIAL PRIMARY KEY,
                emp_id VARCHAR(50) REFERENCES employees(emp_id),
                violation_type VARCHAR(100),
                violation_date DATE,
                description TEXT,
                severity VARCHAR(50)
            );

            -- 샘플 데이터
            INSERT INTO departments (dept_name, dept_type) VALUES
            ('경영지원실', '본사_지원'),
            ('기술지원본부', '본사_기술'),
            ('미래전략TF', 'TF');

            INSERT INTO sites (site_name, location, safety_score) VALUES
            ('7번 현장', '대구 수성구', 96.0),
            ('12번 현장', '서울 강남구', 88.0);

            INSERT INTO employees (emp_id, emp_name, role_level, kpi_score) VALUES
            ('E001', '홍길동', '대표이사', 95.0),
            ('E002', '김현장', '팀장/소장', 88.0),
            ('E003', '박본부', '부서장', 92.0);
        `);

        console.log('✅ 테이블 생성 완료!\n');
        console.log('🎉 데이터베이스 초기화 완료!\n');

    } catch (error) {
        console.error('❌ 초기화 오류:', error.message);
    } finally {
        await client.end();
    }
}

// 서버 시작 전에 DB 초기화
initializeDatabase().then(() => {
    console.log('✅ 초기화 완료. 서버 시작 준비됨.\n');
}).catch(err => {
    console.error('❌ 초기화 실패:', err);
});
