-- Deteksi duplikasi email di tabel dimensi nasabah
SELECT 
    email, 
    COUNT(uniqueid) AS jumlah_id_terdaftar
FROM dw.dim_customer
GROUP BY email
HAVING COUNT(uniqueid) > 1
ORDER BY jumlah_id_terdaftar DESC;

-- Mencari anomali pencairan dana (LTV > 100%)
SELECT 
    loan_key, 
    uniqueid, 
    disbursed_amount, 
    asset_cost, 
    ltv
FROM dw.fact_loan
WHERE disbursed_amount > asset_cost
ORDER BY ltv DESC;

-- Mencari transaksi yang tidak memiliki data nasabah induk (Data Quality Check)
SELECT 
    f.loan_key, 
    f.uniqueid AS id_tidak_dikenal,
    f.date_key
FROM dw.fact_loan f
LEFT JOIN dw.dim_customer c ON f.uniqueid = c.uniqueid
WHERE c.uniqueid IS NULL;

-- Segmentasi umur nasabah (Menggunakan CASE WHEN & Date Math)
SELECT 
    CASE 
        WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, birth_date::date)) < 30 THEN 'Gen Z (Under 30)'
        WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, birth_date::date)) BETWEEN 30 AND 45 THEN 'Millennials (30 - 45)'
        ELSE 'Gen X & Boomers (Over 45)' 
    END AS segmentasi_umur,
    COUNT(uniqueid) AS total_nasabah
FROM dw.dim_customer
GROUP BY segmentasi_umur
ORDER BY total_nasabah DESC;

-- Segmentasi umur nasabah (Menggunakan CASE WHEN & Date Math)
SELECT 
    CASE 
        WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, birth_date::date)) < 30 THEN 'Gen Z (Under 30)'
        WHEN EXTRACT(YEAR FROM AGE(CURRENT_DATE, birth_date::date)) BETWEEN 30 AND 45 THEN 'Millennials (30 - 45)'
        ELSE 'Gen X & Boomers (Over 45)' 
    END AS segmentasi_umur,
    COUNT(uniqueid) AS total_nasabah
FROM dw.dim_customer
GROUP BY segmentasi_umur
ORDER BY total_nasabah DESC;

-- Mengukur tingkat retensi/kekerapan meminjam nasabah
WITH Frequency AS (
    SELECT uniqueid, COUNT(loan_key) as total_pinjaman
    FROM dw.fact_loan
    GROUP BY uniqueid
)
SELECT 
    CASE 
        WHEN total_pinjaman = 1 THEN '1. Nasabah Baru / Sekali Pinjam'
        WHEN total_pinjaman BETWEEN 2 AND 3 THEN '2. Jarang Meminjam (2-3x)'
        ELSE '3. Nasabah Setia (>3x)' 
    END AS tingkat_loyalitas,
    COUNT(uniqueid) AS jumlah_nasabah
FROM Frequency
GROUP BY tingkat_loyalitas
ORDER BY tingkat_loyalitas ASC;


-- Total nilai pinjaman berdasarkan jenis pekerjaan
SELECT 
    e.employment_type AS profesi,
    COUNT(l.loan_key) AS total_transaksi,
    SUM(l.disbursed_amount) AS total_portfolio_cair
FROM dw.fact_loan l
JOIN dw.dim_employment e ON l.employment_key = e.employment_key
GROUP BY e.employment_type
ORDER BY total_portfolio_cair DESC;

-- Menghitung rasio kredit macet (Default Rate / NPL) global
SELECT 
    COUNT(loan_key) AS total_pencairan,
    SUM(loan_default) AS total_kasus_macet,
    ROUND((SUM(loan_default) * 100.0) / COUNT(loan_key), 2) AS rasio_npl_persen
FROM dw.fact_loan;

-- Korelasi jumlah *inquiries* sebelum pinjaman cair dengan probabilitas gagal bayar
SELECT 
    no_of_inquiries AS jumlah_investigasi,
    COUNT(loan_key) AS total_pengajuan,
    ROUND((SUM(loan_default) * 100.0) / COUNT(loan_key), 2) AS kemungkinan_macet_persen
FROM dw.fact_loan
GROUP BY no_of_inquiries
ORDER BY no_of_inquiries ASC;

-- Mengukur akurasi *credit score* internal terhadap kenyataan macet di lapangan
SELECT 
    CASE 
        WHEN perform_cns_score < 300 THEN 'High Risk (Score < 300)'
        WHEN perform_cns_score BETWEEN 300 AND 600 THEN 'Medium Risk (Score 300-600)'
        ELSE 'Low Risk (Score > 600)' 
    END AS credit_risk_tier,
    COUNT(loan_key) AS total_pinjaman,
    ROUND((SUM(loan_default) * 100.0) / COUNT(loan_key), 2) AS actual_default_rate_persen
FROM dw.fact_loan
GROUP BY credit_risk_tier
ORDER BY actual_default_rate_persen DESC;

-- Analisis pertumbuhan transaksi hari-ke-hari (DoD)
WITH DailyTransactions AS (
    SELECT 
        date_key, 
        COUNT(loan_key) AS jumlah_transaksi
    FROM dw.fact_loan
    GROUP BY date_key
)
SELECT 
    date_key,
    jumlah_transaksi,
    LAG(jumlah_transaksi) OVER(ORDER BY date_key ASC) AS transaksi_hari_sebelumnya,
    jumlah_transaksi - LAG(jumlah_transaksi) OVER(ORDER BY date_key ASC) AS selisih_pertumbuhan
FROM DailyTransactions;

-- Menghitung akumulasi pencairan dana berjalan (Running Total) menggunakan Window Function
WITH DailyAmount AS (
    SELECT 
        d.full_date, 
        SUM(l.disbursed_amount) AS total_harian
    FROM dw.fact_loan l
    JOIN dw.dim_date d ON l.date_key = d.date_key
    GROUP BY d.full_date
)
SELECT 
    full_date,
    total_harian,
    SUM(total_harian) OVER(ORDER BY full_date ASC) AS akumulasi_total_cair_berjalan
FROM DailyAmount;

-- Menentukan hari paling sibuk dalam operasional pinjaman
SELECT 
    TO_CHAR(d.full_date::date, 'Day') AS hari_operasional,
    COUNT(l.loan_key) AS volume_transaksi,
    SUM(l.disbursed_amount) AS total_rupiah_cair
FROM dw.fact_loan l
JOIN dw.dim_date d ON l.date_key = d.date_key
GROUP BY hari_operasional
ORDER BY volume_transaksi DESC;


-- Persentase kontribusi pencairan cabang terhadap pendapatan nasional perusahaan
SELECT DISTINCT
    b.branch_name,
    SUM(l.disbursed_amount) OVER(PARTITION BY b.branch_name) AS total_cair_cabang,
    SUM(l.disbursed_amount) OVER() AS total_cair_nasional,
    ROUND((SUM(l.disbursed_amount) OVER(PARTITION BY b.branch_name) * 100.0) / 
          SUM(l.disbursed_amount) OVER(), 2) AS persentase_kontribusi
FROM dw.fact_loan l
JOIN dw.dim_branch b ON l.branch_key = b.branch_key
ORDER BY persentase_kontribusi DESC;

-- Mendeteksi nasabah yang jumlah pinjamannya meningkat (Upscaling Analysis)
WITH RankedLoans AS (
    SELECT 
        uniqueid, 
        disbursed_amount,
        ROW_NUMBER() OVER(PARTITION BY uniqueid ORDER BY date_key ASC) AS pinjaman_ke,
        COUNT(*) OVER(PARTITION BY uniqueid) AS total_kali_pinjam
    FROM dw.fact_loan
)
SELECT 
    a.uniqueid,
    a.disbursed_amount AS nominal_pinjaman_pertama,
    b.disbursed_amount AS nominal_pinjaman_terakhir,
    (b.disbursed_amount - a.disbursed_amount) AS selisih_peningkatan
FROM RankedLoans a
JOIN RankedLoans b ON a.uniqueid = b.uniqueid
WHERE a.pinjaman_ke = 1 
  AND b.pinjaman_ke = b.total_kali_pinjam 
  AND b.total_kali_pinjam > 1 -- Hanya untuk nasabah yang meminjam lebih dari 1 kali
  AND b.disbursed_amount > a.disbursed_amount -- Hanya tampilkan yang nominalnya naik
LIMIT 15;


-- Nasabah prioritas penagihan di masing-masing kategori kredit (Top 1 per Partition)
WITH RankingPenagihan AS (
    SELECT 
        c.customer_name,
        cs.score_tier, -- Asumsi kolom ini ada di dim_credit_score
        l.pri_current_balance AS sisa_tagihan,
        ROW_NUMBER() OVER(PARTITION BY cs.score_key ORDER BY l.pri_current_balance DESC) AS peringkat_tagihan
    FROM dw.fact_loan l
    JOIN dw.dim_customer c ON l.uniqueid = c.uniqueid
    JOIN dw.dim_credit_score cs ON l.score_key = cs.score_key
    WHERE l.loan_default = 1 -- Hanya nasabah macet
)
SELECT 
    score_tier AS kategori_risiko,
    customer_name AS nama_nasabah_target,
    sisa_tagihan AS nominal_tunggakan
FROM RankingPenagihan
WHERE peringkat_tagihan = 1;