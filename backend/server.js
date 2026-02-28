// ========================================
// S-FRAME API Server (Production Ready)
// Node.js + Express + PostgreSQL
// ========================================

const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// 미들웨어
app.use(cors());
app.use(express.json());

// PostgreSQL 연결
const pool = new Pool({
    connectionString: process.env.DATABASE_URL,
    ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false
});

// 정적 파일 서빙 (프론트엔드 연동)
const path = require('path');
app.use(express.static(path.join(__dirname, '../frontend')));


// 연결 테스트
pool.query('SELECT NOW()', (err, res) => {
    if (err) {
        console.error('❌ Database connection failed:', err);
    } else {
        console.log('✅ Database connected:', res.rows[0].now);
    }
});

// ========================================
// API 엔드포인트
// ========================================

// 1. 로그인
app.post('/api/auth/login', async (req, res) => {
    try {
        const { empId } = req.body;
        const result = await pool.query(
            'SELECT emp_id, emp_name, role_level FROM employees WHERE emp_id = $1',
            [empId]
        );
        
        if (result.rows.length > 0) {
            res.json({ success: true, user: result.rows[0] });
        } else {
            res.status(401).json({ error: '사원번호를 확인하세요' });
        }
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// 2. 직원 목록
app.get('/api/employees', async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT e.emp_id, e.emp_name, d.dept_name, s.site_name, e.role_level, e.kpi_score
            FROM employees e
            LEFT JOIN departments d ON e.dept_id = d.dept_id
            LEFT JOIN sites s ON e.site_id = s.site_id
            WHERE e.is_active = true
        `);
        res.json(result.rows);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// 3. KPI 저장
app.post('/api/kpi', async (req, res) => {
    try {
        const { empId, kpiScore } = req.body;
        const result = await pool.query(
            'UPDATE employees SET kpi_score = $1 WHERE emp_id = $2 RETURNING *',
            [kpiScore, empId]
        );
        res.json(result.rows[0]);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// 4. 평가 저장
app.post('/api/evaluations', async (req, res) => {
    try {
        const { evaluatedEmpId, evaluatorEmpId, evalYear, evalPeriod, competencyScore, sincerityScore } = req.body;
        const totalScore = competencyScore + sincerityScore;
        
        const result = await pool.query(`
            INSERT INTO evaluations (evaluated_emp_id, evaluator_emp_id, evaluator_role, eval_year, eval_period, competency_score, sincerity_score, total_score)
            VALUES ($1, $2, 'User', $3, $4, $5, $6, $7)
            RETURNING *
        `, [evaluatedEmpId, evaluatorEmpId, evalYear, evalPeriod, competencyScore, sincerityScore, totalScore]);
        
        res.json(result.rows[0]);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// 5. 안전 위반 기록
app.post('/api/safety-violations', async (req, res) => {
    try {
        const { empId, violationType, violationDate, description } = req.body;
        
        await pool.query(
            'INSERT INTO safety_violations (emp_id, violation_type, violation_date, description, severity) VALUES ($1, $2, $3, $4, $5)',
            [empId, violationType, violationDate, description, '중대']
        );
        
        await pool.query('UPDATE employees SET safety_violations = safety_violations + 1 WHERE emp_id = $1', [empId]);
        
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// 6. 최종 등급 계산
app.post('/api/calculate-grade', async (req, res) => {
    try {
        const { empId, evalYear, evalPeriod } = req.body;
        
        const empResult = await pool.query('SELECT * FROM employees WHERE emp_id = $1', [empId]);
        const employee = empResult.rows[0];
        
        const evalResult = await pool.query(
            'SELECT AVG(total_score) as avg_score FROM evaluations WHERE evaluated_emp_id = $1',
            [empId]
        );
        
        const baseScore = parseFloat(evalResult.rows[0].avg_score || employee.kpi_score || 80);
        const bonusScore = 3; // 예시
        
        let penaltyMultiplier = 1.0;
        if (employee.safety_violations === 1) penaltyMultiplier = 0.9;
        else if (employee.safety_violations >= 2) penaltyMultiplier = 0.0;
        
        const finalScore = (baseScore + bonusScore) * penaltyMultiplier;
        
        let finalGrade;
        if (finalScore >= 95) finalGrade = 'S';
        else if (finalScore >= 85) finalGrade = 'A';
        else if (finalScore >= 70) finalGrade = 'B';
        else if (finalScore >= 50) finalGrade = 'C';
        else finalGrade = 'F';
        
        res.json({
            empName: employee.emp_name,
            baseScore,
            bonusScore,
            finalScore: finalScore.toFixed(1),
            finalGrade,
            violations: employee.safety_violations
        });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// 7. 대시보드 통계
app.get('/api/dashboard/stats', async (req, res) => {
    try {
        const result = await pool.query(`
            SELECT
                (SELECT COUNT(*) FROM employees WHERE is_active = true) as total_employees,
                (SELECT ROUND(AVG(kpi_score)::numeric, 1) FROM employees) as avg_kpi,
                (SELECT COUNT(*) FROM sites) as total_sites
        `);
        res.json(result.rows[0]);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
});

// Health Check
app.get('/health', (req, res) => {
    res.json({ status: 'ok' });
});

// 서버 시작
app.listen(PORT, () => {
    console.log(`🚀 S-FRAME API Server running on port ${PORT}`);
});
