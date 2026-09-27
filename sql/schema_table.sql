-- Membuat skema Data Warehouse
CREATE SCHEMA IF NOT EXISTS dw;

-- ==========================================
-- 1. PEMBUATAN TABEL DIMENSI (DIMENSION TABLES)
-- ==========================================

-- Tabel Dimensi Waktu
CREATE TABLE dw.dim_date (
    date_key INT4 PRIMARY KEY,
    full_date DATE,
    year INT4,
    month INT4,
    day INT4,
    quarter INT4
);

-- Tabel Dimensi Cabang
CREATE TABLE dw.dim_branch (
    branch_key INT4 PRIMARY KEY,
    branch_id INT4,
    branch_name VARCHAR
);

-- Tabel Dimensi Pekerjaan
CREATE TABLE dw.dim_employment (
    employment_key INT4 PRIMARY KEY,
    employment_type VARCHAR
);

-- Tabel Dimensi Skor Kredit
CREATE TABLE dw.dim_credit_score (
    score_key INT4 PRIMARY KEY,
    score_description VARCHAR
);

-- Tabel Dimensi Nasabah
CREATE TABLE dw.dim_customer (
    customer_key INT4 PRIMARY KEY,
    
    -- uniqueid diset UNIQUE agar bisa menjadi referensi (Target Foreign Key) dari fact_loan
    uniqueid INT8 UNIQUE, 
    
    birth_date DATE,
    age INT4,
    employment_type VARCHAR,
    state_id INT4,
    pincode_id INT4,
    customer_name VARCHAR,
    gender VARCHAR,
    email VARCHAR,
    phone_number VARCHAR,
    address TEXT
);

-- ==========================================
-- 2. PEMBUATAN TABEL FAKTA (FACT TABLE)
-- ==========================================

-- Tabel Fakta Pinjaman
CREATE TABLE dw.fact_loan (
    loan_key INT8 PRIMARY KEY,
    uniqueid INT8,
    date_key INT4,
    branch_key INT4,
    employment_key INT4,
    score_key INT4,
    disbursed_amount NUMERIC,
    asset_cost NUMERIC,
    ltv NUMERIC,
    perform_cns_score INT4,
    pri_current_balance NUMERIC,
    pri_sanctioned_amount NUMERIC,
    pri_disbursed_amount NUMERIC,
    no_of_inquiries INT4,
    loan_default INT4,

    -- ==========================================
    -- 3. PENDEKLARASIAN RELASI (FOREIGN KEYS)
    -- ==========================================
    
    -- Relasi ke Tabel Nasabah (Menggunakan uniqueid sesuai ERD)
    FOREIGN KEY (uniqueid) REFERENCES dw.dim_customer(uniqueid),
    
    -- Relasi ke Tabel Dimensi Lainnya
    FOREIGN KEY (date_key) REFERENCES dw.dim_date(date_key),
    FOREIGN KEY (branch_key) REFERENCES dw.dim_branch(branch_key),
    FOREIGN KEY (employment_key) REFERENCES dw.dim_employment(employment_key),
    FOREIGN KEY (score_key) REFERENCES dw.dim_credit_score(score_key)
);