-- ============================================================
-- 02 — BRONZE LAYER — Controllo di Data Quality
-- Controlli eseguiti su bronze.application, bronze.bureau,
-- bronze.previous_application. Le anomalie trovate qui
-- determinano le regole di pulizia del layer Silver.
-- ============================================================

USE credit_risk;
GO

-- ------------------------------------------------------------
-- 1) DUPLICATI SULLE CHIAVI
-- Nessuna riga attesa in output se le chiavi sono davvero uniche.
-- ------------------------------------------------------------

SELECT SK_ID_CURR, COUNT(*) AS n
FROM bronze.application
GROUP BY SK_ID_CURR
HAVING COUNT(*) > 1;

SELECT SK_ID_BUREAU, COUNT(*) AS n
FROM bronze.bureau
GROUP BY SK_ID_BUREAU
HAVING COUNT(*) > 1;

SELECT SK_ID_PREV, COUNT(*) AS n
FROM bronze.previous_application
GROUP BY SK_ID_PREV
HAVING COUNT(*) > 1;

-- Risultato: nessun duplicato su nessuna delle 3 chiavi.

-- ------------------------------------------------------------
-- 2) NULL/VUOTI SULLE COLONNE CHIAVE DI application
-- ------------------------------------------------------------

SELECT
    SUM(CASE WHEN TARGET             IS NULL OR TARGET             = '' THEN 1 ELSE 0 END) AS null_target,
    SUM(CASE WHEN AMT_INCOME_TOTAL    IS NULL OR AMT_INCOME_TOTAL    = '' THEN 1 ELSE 0 END) AS null_income,
    SUM(CASE WHEN AMT_CREDIT          IS NULL OR AMT_CREDIT          = '' THEN 1 ELSE 0 END) AS null_credit,
    SUM(CASE WHEN DAYS_BIRTH          IS NULL OR DAYS_BIRTH          = '' THEN 1 ELSE 0 END) AS null_days_birth,
    SUM(CASE WHEN DAYS_EMPLOYED       IS NULL OR DAYS_EMPLOYED       = '' THEN 1 ELSE 0 END) AS null_days_employed,
    SUM(CASE WHEN EXT_SOURCE_1        IS NULL OR EXT_SOURCE_1        = '' THEN 1 ELSE 0 END) AS null_ext_source_1,
    SUM(CASE WHEN EXT_SOURCE_2        IS NULL OR EXT_SOURCE_2        = '' THEN 1 ELSE 0 END) AS null_ext_source_2,
    SUM(CASE WHEN EXT_SOURCE_3        IS NULL OR EXT_SOURCE_3        = '' THEN 1 ELSE 0 END) AS null_ext_source_3,
    SUM(CASE WHEN OCCUPATION_TYPE     IS NULL OR OCCUPATION_TYPE     = '' THEN 1 ELSE 0 END) AS null_occupation,
    SUM(CASE WHEN NAME_EDUCATION_TYPE IS NULL OR NAME_EDUCATION_TYPE = '' THEN 1 ELSE 0 END) AS null_education
FROM bronze.application;

-- Risultato: TARGET/income/credit/days_birth/education senza null.
-- EXT_SOURCE_1 ~54% null (poco affidabile da solo per lo scoring),
-- EXT_SOURCE_2 ~2,4% null (il piu' completo, candidato principale),
-- EXT_SOURCE_3 ~19% null, OCCUPATION_TYPE ~30% null (va trattata
-- come categoria propria in Silver, non scartata).

-- ------------------------------------------------------------
-- 3) SENTINELLA E RANGE SU DAYS_EMPLOYED / AMT_INCOME_TOTAL
-- ------------------------------------------------------------

SELECT
    SUM(CASE WHEN DAYS_EMPLOYED = '365243' THEN 1 ELSE 0 END) AS n_sentinella_365243,
    MIN(TRY_CAST(DAYS_EMPLOYED AS FLOAT))     AS min_days_employed,
    MAX(TRY_CAST(DAYS_EMPLOYED AS FLOAT))     AS max_days_employed,
    AVG(TRY_CAST(DAYS_EMPLOYED AS FLOAT))     AS avg_days_employed,
    MIN(TRY_CAST(AMT_INCOME_TOTAL AS FLOAT))  AS min_income,
    MAX(TRY_CAST(AMT_INCOME_TOTAL AS FLOAT))  AS max_income,
    AVG(TRY_CAST(AMT_INCOME_TOTAL AS FLOAT))  AS avg_income
FROM bronze.application;

-- Risultato: 53.667 righe (~17,5%) con sentinella 365243 su
-- DAYS_EMPLOYED -> in Silver: flag IS_EMPLOYED/FLAG_PENSIONATO
-- + NULL sul valore (non reinterpretare come numero).
-- AMT_INCOME_TOTAL: max 117.000.000 contro una media di 168.798
-- (693x la media) -> vedi punto 4 per l'analisi dell'outlier.

-- ------------------------------------------------------------
-- 4) OUTLIER SU AMT_INCOME_TOTAL — Q1/Q3, soglia di Tukey,
-- e analisi del gap fra i valori piu' alti
-- ------------------------------------------------------------

-- Q1 e Q3
SELECT DISTINCT
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY TRY_CAST(AMT_INCOME_TOTAL AS FLOAT)) OVER () AS q1_income,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY TRY_CAST(AMT_INCOME_TOTAL AS FLOAT)) OVER () AS q3_income
FROM bronze.application;
-- Risultato: Q1 = 112.500, Q3 = 202.500 -> IQR = 90.000
-- Soglia di Tukey (Q3 + 1,5*IQR) = 337.500

-- Quante righe superano la soglia di Tukey?
SELECT COUNT(*) AS n_outlier_income
FROM bronze.application
WHERE TRY_CAST(AMT_INCOME_TOTAL AS FLOAT) > 337500;
-- Risultato: 14.035 righe (~4,6%) — troppe per un reddito, che e'
-- naturalmente asimmetrico a destra. La regola di Tukey da sola
-- marchierebbe come outlier un segmento legittimo di redditi alti.

-- Analisi del gap fra i valori piu' alti (isola l'anomalia vera)
WITH top_incomes AS (
    SELECT TOP 50 TRY_CAST(AMT_INCOME_TOTAL AS FLOAT) AS income
    FROM bronze.application
    ORDER BY TRY_CAST(AMT_INCOME_TOTAL AS FLOAT) DESC
)
SELECT
    income,
    LEAD(income) OVER (ORDER BY income DESC) AS prossimo_reddito,
    income - LEAD(income) OVER (ORDER BY income DESC) AS salto
FROM top_incomes
ORDER BY income DESC;

-- Risultato: salto di ~99.000.000 fra 117.000.000 e 18.000.090
-- (~22 volte il salto successivo piu' grande) -> un solo valore
-- isolato e realmente anomalo. Il resto della coda (fino a ~18M)
-- scende gradualmente: probabile segmento reale di redditi molto
-- alti, non errori. Decisione: solo 117.000.000 -> NULL in Silver,
-- il resto della coda resta invariato.

-- ------------------------------------------------------------
-- 5) VALORI CATEGORICI INVALIDI ('XNA')
-- ------------------------------------------------------------

SELECT
    SUM(CASE WHEN CODE_GENDER        = 'XNA' THEN 1 ELSE 0 END) AS xna_gender,
    SUM(CASE WHEN ORGANIZATION_TYPE  = 'XNA' THEN 1 ELSE 0 END) AS xna_organization,
    SUM(CASE WHEN NAME_FAMILY_STATUS = 'XNA' THEN 1 ELSE 0 END) AS xna_family_status,
    SUM(CASE WHEN NAME_INCOME_TYPE   = 'XNA' THEN 1 ELSE 0 END) AS xna_income_type
FROM bronze.application;

-- ------------------------------------------------------------
-- 6) COPERTURA FRA TABELLE — quanti clienti di application hanno
-- almeno una riga in bureau / previous_application
-- ------------------------------------------------------------

SELECT COUNT(DISTINCT a.SK_ID_CURR) AS clienti_con_bureau
FROM bronze.application a
INNER JOIN bronze.bureau b ON a.SK_ID_CURR = b.SK_ID_CURR;

SELECT COUNT(DISTINCT a.SK_ID_CURR) AS clienti_con_previous_application
FROM bronze.application a
INNER JOIN bronze.previous_application p ON a.SK_ID_CURR = p.SK_ID_CURR;

-- Confrontare col totale application (307.511) per la percentuale
-- di copertura.

-- ------------------------------------------------------------
-- 7) REGRESSIONE — colonne AMT_REQ_CREDIT_BUREAU_* di application
-- e previous_application non devono contenere piu' virgole
-- (bug di quoting CSV risolto con FORMAT='CSV'+FIELDQUOTE in
-- 01_bronze_load.sql — vedi wiki/log.md)
-- ------------------------------------------------------------

SELECT
    SUM(CASE WHEN AMT_REQ_CREDIT_BUREAU_HOUR LIKE '%,%' THEN 1 ELSE 0 END) AS virgole_hour,
    SUM(CASE WHEN AMT_REQ_CREDIT_BUREAU_DAY  LIKE '%,%' THEN 1 ELSE 0 END) AS virgole_day,
    SUM(CASE WHEN AMT_REQ_CREDIT_BUREAU_WEEK LIKE '%,%' THEN 1 ELSE 0 END) AS virgole_week,
    SUM(CASE WHEN AMT_REQ_CREDIT_BUREAU_MON  LIKE '%,%' THEN 1 ELSE 0 END) AS virgole_mon,
    SUM(CASE WHEN AMT_REQ_CREDIT_BUREAU_QRT  LIKE '%,%' THEN 1 ELSE 0 END) AS virgole_qrt,
    SUM(CASE WHEN AMT_REQ_CREDIT_BUREAU_YEAR LIKE '%,%' THEN 1 ELSE 0 END) AS virgole_year
FROM bronze.application;

-- Risultato atteso: tutti zero.
