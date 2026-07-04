-- ============================================================
-- 03 — SILVER LAYER — silver.application, silver.bureau,
-- silver.previous_application
-- Tipizzazione dei campi dalle 3 tabelle bronze (tutto NVARCHAR)
-- e pulizia dei valori anomali identificati in fase di QC
-- (vedi docs/02_bronze_quality_check.sql e wiki/log.md).
-- ============================================================

USE credit_risk;
GO


-- ------------------------------------------------------------
-- silver.application
--
-- Pulizia applicata:
--   - DAYS_EMPLOYED: sentinella 365243 -> flag FLAG_PENSIONATO
--     (1/0) + valore messo a NULL invece che reinterpretato.
--     Il confronto usa MAX(...) OVER () invece del numero
--     365243 "hardcoded", cosi' si adatta se il dataset cambia.
--   - AMT_INCOME_TOTAL: unico outlier isolato (117.000.000,
--     individuato con analisi del gap tramite LEAD) -> NULL.
--   - CODE_GENDER / ORGANIZATION_TYPE: valore placeholder 'XNA'
--     (dato mancante mascherato da categoria) -> NULL.
--   - NAME_FAMILY_STATUS: valore placeholder 'Unknown' -> NULL.
-- Aggiunge anche due bucket di segmentazione (fascia_eta da
-- DAYS_BIRTH, fascia_reddito da AMT_INCOME_TOTAL), utili come
-- dimensioni per la segmentazione nel layer Gold/Power BI.
--
-- NOTA sui TRY_CAST a INT: alcune colonne numeriche del CSV sono
-- scritte con ".0" (es. CNT_FAM_MEMBERS = "2.0", AMT_REQ_CREDIT_
-- BUREAU_* = "0.0"/"1.0"...). Un TRY_CAST diretto stringa->INT
-- fallisce (restituisce NULL) se c'e' un punto decimale nella
-- stringa — stesso bug intercettato su AMT_INCOME_TOTAL. Per
-- queste colonne si passa quindi prima da FLOAT e poi a INT.
-- ------------------------------------------------------------

DROP TABLE IF EXISTS silver.application;
GO

CREATE TABLE silver.application (
    sk_id_curr                     INT,
    target                         INT,
    name_contract_type             NVARCHAR(100),
    amt_income_total               DECIMAL(10,1),
    amt_credit                     DECIMAL(10,1),
    amt_annuity                    DECIMAL(10,1),
    amt_goods_price                DECIMAL(10,1),
    code_gender                    NVARCHAR(100),
    cnt_children                   INT,
    cnt_fam_members                INT,
    name_family_status             NVARCHAR(100),
    days_birth                     INT,
    name_income_type               NVARCHAR(100),
    name_education_type            NVARCHAR(100),
    occupation_type                NVARCHAR(100),
    flag_pensionato                INT,
    organization_type              NVARCHAR(100),
    days_employed                  INT,
    name_housing_type              NVARCHAR(100),
    flag_own_car                   NVARCHAR(100),
    flag_own_realty                NVARCHAR(100),
    ext_source_1                   FLOAT,
    ext_source_2                   FLOAT,
    ext_source_3                   FLOAT,
    amt_req_credit_bureau_hour     INT,
    amt_req_credit_bureau_day      INT,
    amt_req_credit_bureau_week     INT,
    amt_req_credit_bureau_mon      INT,
    amt_req_credit_bureau_qrt      INT,
    amt_req_credit_bureau_year     INT,
    fascia_eta                     NVARCHAR(20),
    fascia_reddito                 NVARCHAR(20)
);
GO

INSERT INTO silver.application (
    sk_id_curr, target, name_contract_type, amt_income_total, amt_credit, amt_annuity,
    amt_goods_price, code_gender, cnt_children, cnt_fam_members, name_family_status,
    days_birth, name_income_type, name_education_type, occupation_type, flag_pensionato,
    organization_type, days_employed, name_housing_type, flag_own_car, flag_own_realty,
    ext_source_1, ext_source_2, ext_source_3, amt_req_credit_bureau_hour,
    amt_req_credit_bureau_day, amt_req_credit_bureau_week, amt_req_credit_bureau_mon,
    amt_req_credit_bureau_qrt, amt_req_credit_bureau_year, fascia_eta, fascia_reddito
)
SELECT
    TRY_CAST(SK_ID_CURR AS INT)                                       AS sk_id_curr,
    TRY_CAST(TARGET AS INT)                                           AS target,
    NAME_CONTRACT_TYPE                                                AS name_contract_type,
    CASE WHEN TRY_CAST(AMT_INCOME_TOTAL AS DECIMAL(10,1)) = 117000000.0
         THEN NULL
         ELSE TRY_CAST(AMT_INCOME_TOTAL AS DECIMAL(10,1))
    END                                                                AS amt_income_total,
    TRY_CAST(AMT_CREDIT AS DECIMAL(10,1))                              AS amt_credit,
    TRY_CAST(AMT_ANNUITY AS DECIMAL(10,1))                             AS amt_annuity,
    TRY_CAST(AMT_GOODS_PRICE AS DECIMAL(10,1))                         AS amt_goods_price,
    CASE WHEN CODE_GENDER = 'XNA' THEN NULL ELSE CODE_GENDER END       AS code_gender,
    TRY_CAST(CNT_CHILDREN AS INT)                                      AS cnt_children,
    TRY_CAST(TRY_CAST(CNT_FAM_MEMBERS AS FLOAT) AS INT)                AS cnt_fam_members,
    CASE WHEN NAME_FAMILY_STATUS = 'Unknown' THEN NULL ELSE NAME_FAMILY_STATUS END
                                                                        AS name_family_status,
    TRY_CAST(DAYS_BIRTH AS INT)                                        AS days_birth,
    NAME_INCOME_TYPE                                                   AS name_income_type,
    NAME_EDUCATION_TYPE                                                AS name_education_type,
    OCCUPATION_TYPE                                                    AS occupation_type,
    CASE WHEN TRY_CAST(DAYS_EMPLOYED AS INT) = MAX(TRY_CAST(DAYS_EMPLOYED AS INT)) OVER ()
         THEN 1 ELSE 0
    END                                                                AS flag_pensionato,
    CASE WHEN ORGANIZATION_TYPE = 'XNA' THEN NULL ELSE ORGANIZATION_TYPE END
                                                                        AS organization_type,
    CASE WHEN TRY_CAST(DAYS_EMPLOYED AS INT) = MAX(TRY_CAST(DAYS_EMPLOYED AS INT)) OVER ()
         THEN NULL
         ELSE TRY_CAST(DAYS_EMPLOYED AS INT)
    END                                                                AS days_employed,
    NAME_HOUSING_TYPE                                                  AS name_housing_type,
    FLAG_OWN_CAR                                                       AS flag_own_car,
    FLAG_OWN_REALTY                                                    AS flag_own_realty,
    TRY_CAST(EXT_SOURCE_1 AS FLOAT)                                    AS ext_source_1,
    TRY_CAST(EXT_SOURCE_2 AS FLOAT)                                    AS ext_source_2,
    TRY_CAST(EXT_SOURCE_3 AS FLOAT)                                    AS ext_source_3,
    TRY_CAST(TRY_CAST(AMT_REQ_CREDIT_BUREAU_HOUR AS FLOAT) AS INT)     AS amt_req_credit_bureau_hour,
    TRY_CAST(TRY_CAST(AMT_REQ_CREDIT_BUREAU_DAY  AS FLOAT) AS INT)     AS amt_req_credit_bureau_day,
    TRY_CAST(TRY_CAST(AMT_REQ_CREDIT_BUREAU_WEEK AS FLOAT) AS INT)     AS amt_req_credit_bureau_week,
    TRY_CAST(TRY_CAST(AMT_REQ_CREDIT_BUREAU_MON  AS FLOAT) AS INT)     AS amt_req_credit_bureau_mon,
    TRY_CAST(TRY_CAST(AMT_REQ_CREDIT_BUREAU_QRT  AS FLOAT) AS INT)     AS amt_req_credit_bureau_qrt,
    TRY_CAST(TRY_CAST(AMT_REQ_CREDIT_BUREAU_YEAR AS FLOAT) AS INT)     AS amt_req_credit_bureau_year,
    CASE
        WHEN ABS(TRY_CAST(DAYS_BIRTH AS INT)) / 365 BETWEEN 18 AND 25 THEN '18-25'
        WHEN ABS(TRY_CAST(DAYS_BIRTH AS INT)) / 365 BETWEEN 26 AND 35 THEN '26-35'
        WHEN ABS(TRY_CAST(DAYS_BIRTH AS INT)) / 365 BETWEEN 36 AND 45 THEN '36-45'
        WHEN ABS(TRY_CAST(DAYS_BIRTH AS INT)) / 365 BETWEEN 46 AND 60 THEN '46-60'
        WHEN ABS(TRY_CAST(DAYS_BIRTH AS INT)) / 365 > 60              THEN '60+'
        ELSE 'N/D'
    END                                                                AS fascia_eta,
    CASE
        WHEN TRY_CAST(AMT_INCOME_TOTAL AS DECIMAL(10,1)) = 117000000.0 THEN NULL
        WHEN TRY_CAST(AMT_INCOME_TOTAL AS DECIMAL(10,1)) < 100000      THEN 'Basso'
        WHEN TRY_CAST(AMT_INCOME_TOTAL AS DECIMAL(10,1)) < 150000      THEN 'Medio-basso'
        WHEN TRY_CAST(AMT_INCOME_TOTAL AS DECIMAL(10,1)) < 250000      THEN 'Medio'
        WHEN TRY_CAST(AMT_INCOME_TOTAL AS DECIMAL(10,1)) < 400000      THEN 'Alto'
        ELSE 'Molto alto'
    END                                                                AS fascia_reddito
FROM bronze.application;
GO

-- Verifica: il conteggio deve tornare 307511
SELECT COUNT(*) AS righe_caricate FROM silver.application;
GO


-- ------------------------------------------------------------
-- silver.bureau
--
-- NOTA: CREDIT_CURRENCY nel dataset e' una stringa categorica
-- (es. "currency 1", "currency 2"...), qui ridotta al solo
-- codice numerico (1, 2, 3, 4) per semplicita' — resta comunque
-- un'etichetta, non va usata in calcoli aritmetici.
--
-- NOTA sui TRY_CAST: come per application, alcune colonne DAYS_*
-- e AMT_* sono scritte nel CSV con ".0" finale — verificato sul
-- sorgente: DAYS_CREDIT_ENDDATE e DAYS_ENDDATE_FACT ce l'hanno
-- (es. "-153.0"), DAYS_CREDIT e DAYS_CREDIT_UPDATE no (es. "-497").
-- Doppio cast (FLOAT poi INT) solo dove serve, per evitare di
-- azzerare la colonna in silenzio con un TRY_CAST diretto a INT.
-- ------------------------------------------------------------

DROP TABLE IF EXISTS silver.bureau;
GO

CREATE TABLE silver.bureau (
    sk_id_curr                 INT,
    sk_id_bureau                INT,
    credit_active               NVARCHAR(100),
    credit_currency              INT,
    days_credit                 INT,
    credit_day_overdue           INT,
    days_credit_enddate          INT,
    days_enddate_fact            INT,
    amt_credit_max_overdue        DECIMAL(10,1),
    cnt_credit_prolong           INT,
    amt_credit_sum               DECIMAL(10,1),
    amt_credit_sum_debt          DECIMAL(10,1),
    amt_credit_sum_limit         DECIMAL(10,1),
    amt_credit_sum_overdue       DECIMAL(10,1),
    credit_type                 NVARCHAR(100),
    days_credit_update           INT,
    amt_annuity                 DECIMAL(10,1)
);
GO

INSERT INTO silver.bureau (
    sk_id_curr, sk_id_bureau, credit_active, credit_currency, days_credit, credit_day_overdue,
    days_credit_enddate, days_enddate_fact, amt_credit_max_overdue, cnt_credit_prolong,
    amt_credit_sum, amt_credit_sum_debt, amt_credit_sum_limit, amt_credit_sum_overdue,
    credit_type, days_credit_update, amt_annuity
)
SELECT
    TRY_CAST(SK_ID_CURR AS INT)                                    AS sk_id_curr,
    TRY_CAST(SK_ID_BUREAU AS INT)                                  AS sk_id_bureau,
    CREDIT_ACTIVE                                                  AS credit_active,
    TRY_CAST(RIGHT(CREDIT_CURRENCY, 1) AS INT)                     AS credit_currency,
    TRY_CAST(DAYS_CREDIT AS INT)                                   AS days_credit,
    TRY_CAST(CREDIT_DAY_OVERDUE AS INT)                            AS credit_day_overdue,
    TRY_CAST(TRY_CAST(DAYS_CREDIT_ENDDATE AS FLOAT) AS INT)        AS days_credit_enddate,
    TRY_CAST(TRY_CAST(DAYS_ENDDATE_FACT AS FLOAT) AS INT)          AS days_enddate_fact,
    TRY_CAST(AMT_CREDIT_MAX_OVERDUE AS DECIMAL(10,1))              AS amt_credit_max_overdue,
    TRY_CAST(CNT_CREDIT_PROLONG AS INT)                            AS cnt_credit_prolong,
    TRY_CAST(AMT_CREDIT_SUM AS DECIMAL(10,1))                      AS amt_credit_sum,
    TRY_CAST(AMT_CREDIT_SUM_DEBT AS DECIMAL(10,1))                 AS amt_credit_sum_debt,
    TRY_CAST(AMT_CREDIT_SUM_LIMIT AS DECIMAL(10,1))                AS amt_credit_sum_limit,
    TRY_CAST(AMT_CREDIT_SUM_OVERDUE AS DECIMAL(10,1))              AS amt_credit_sum_overdue,
    CREDIT_TYPE                                                    AS credit_type,
    TRY_CAST(DAYS_CREDIT_UPDATE AS INT)                            AS days_credit_update,
    TRY_CAST(AMT_ANNUITY AS DECIMAL(10,1))                         AS amt_annuity
FROM bronze.bureau;
GO

-- Verifica: il conteggio deve tornare ~1.716.428
SELECT COUNT(*) AS righe_caricate FROM silver.bureau;
GO


-- ------------------------------------------------------------
-- silver.previous_application
--
-- Tenute tutte le 37 colonne (a differenza di application, qui
-- non e' stato fatto un taglio di scope: la tabella e' gia'
-- compatta e serve aggregarla per cliente nella Fase 3, quindi
-- meglio avere tutto disponibile).
--
-- NOTA 1 (stesso bug del punto decimale): verificato sul CSV
-- sorgente, molte colonne DAYS_*/CNT_PAYMENT/NFLAG_* sono scritte
-- con ".0" finale (es. "-42.0", "12.0") — doppio cast FLOAT->INT
-- dove serve, come gia' fatto per application/bureau.
--
-- NOTA 2: DAYS_FIRST_DRAWING, DAYS_FIRST_DUE, DAYS_LAST_DUE_1ST_VERSION,
-- DAYS_LAST_DUE, DAYS_TERMINATION hanno la stessa sentinella 365243
-- vista su DAYS_EMPLOYED. Verificato con GROUP BY su NAME_CONTRACT_STATUS:
-- compare SOLO su prestiti "Approved" (0% su Refused/Canceled/Unused
-- offer, che nel CSV hanno gia' il campo vuoto/NULL di suo), con
-- percentuale crescente quanto piu' l'evento di ciclo di vita e'
-- "lontano" (3,9% prima rata -> 21,8% chiusura, coerente con prestiti
-- ancora attivi che non hanno ancora raggiunto quello stadio).
-- Messo a NULL su tutte e 5, senza flag dedicato (a differenza di
-- DAYS_EMPLOYED): qui l'informazione "era approvato o no" resta gia'
-- disponibile in NAME_CONTRACT_STATUS, quindi un flag per colonna
-- sarebbe ridondante.
-- NOTA 3: CODE_REJECT_REASON con placeholder 'XNA' (0,3%, 5.244 righe)
-- -> NULL, trattato come vera anomalia rara. Le altre colonne con
-- 'XNA' molto frequente (NAME_CASH_LOAN_PURPOSE 40,6%, NAME_PAYMENT_TYPE
-- 37,6%, NAME_GOODS_CATEGORY 56,9%, NAME_PORTFOLIO 22,3%, NAME_PRODUCT_TYPE
-- 63,7%, NAME_SELLER_INDUSTRY 51,2%) NON sono state toccate: percentuali
-- cosi' alte indicano che 'XNA' e' una categoria strutturale ("non si
-- applica a questo tipo di prestito"), non un dato mancante — va
-- distinto da 'XAP' ("non applicabile", altrettanto strutturale, es.
-- 81% su CODE_REJECT_REASON = prestito approvato quindi nessun motivo
-- di rifiuto), anch'esso lasciato invariato.
-- NOTA 4: AMT_DOWN_PAYMENT/RATE_DOWN_PAYMENT con 2 righe negative
-- (anomalia isolata, verificata con check di segno) -> NULL.
-- ------------------------------------------------------------

DROP TABLE IF EXISTS silver.previous_application;
GO

CREATE TABLE silver.previous_application (
    sk_id_prev                     INT,
    sk_id_curr                     INT,
    name_contract_type             NVARCHAR(100),
    amt_annuity                    DECIMAL(10,1),
    amt_application                DECIMAL(10,1),
    amt_credit                     DECIMAL(10,1),
    amt_down_payment               DECIMAL(10,1),
    amt_goods_price                DECIMAL(10,1),
    weekday_appr_process_start     NVARCHAR(20),
    hour_appr_process_start        INT,
    flag_last_appl_per_contract    NVARCHAR(10),
    nflag_last_appl_in_day         INT,
    rate_down_payment              FLOAT,
    rate_interest_primary          FLOAT,
    rate_interest_privileged       FLOAT,
    name_cash_loan_purpose         NVARCHAR(100),
    name_contract_status           NVARCHAR(100),
    days_decision                  INT,
    name_payment_type              NVARCHAR(100),
    code_reject_reason             NVARCHAR(100),
    name_type_suite                NVARCHAR(100),
    name_client_type                NVARCHAR(100),
    name_goods_category            NVARCHAR(100),
    name_portfolio                 NVARCHAR(100),
    name_product_type              NVARCHAR(100),
    channel_type                   NVARCHAR(100),
    sellerplace_area                INT,
    name_seller_industry           NVARCHAR(100),
    cnt_payment                    INT,
    name_yield_group               NVARCHAR(100),
    product_combination            NVARCHAR(150),
    days_first_drawing              INT,
    days_first_due                  INT,
    days_last_due_1st_version        INT,
    days_last_due                   INT,
    days_termination                INT,
    nflag_insured_on_approval        INT
);
GO

INSERT INTO silver.previous_application (
    sk_id_prev, sk_id_curr, name_contract_type, amt_annuity, amt_application, amt_credit,
    amt_down_payment, amt_goods_price, weekday_appr_process_start, hour_appr_process_start,
    flag_last_appl_per_contract, nflag_last_appl_in_day, rate_down_payment, rate_interest_primary,
    rate_interest_privileged, name_cash_loan_purpose, name_contract_status, days_decision,
    name_payment_type, code_reject_reason, name_type_suite, name_client_type, name_goods_category,
    name_portfolio, name_product_type, channel_type, sellerplace_area, name_seller_industry,
    cnt_payment, name_yield_group, product_combination, days_first_drawing, days_first_due,
    days_last_due_1st_version, days_last_due, days_termination, nflag_insured_on_approval
)
SELECT
    TRY_CAST(SK_ID_PREV AS INT)                                        AS sk_id_prev,
    TRY_CAST(SK_ID_CURR AS INT)                                        AS sk_id_curr,
    NAME_CONTRACT_TYPE                                                 AS name_contract_type,
    TRY_CAST(AMT_ANNUITY AS DECIMAL(10,1))                             AS amt_annuity,
    TRY_CAST(AMT_APPLICATION AS DECIMAL(10,1))                         AS amt_application,
    TRY_CAST(AMT_CREDIT AS DECIMAL(10,1))                              AS amt_credit,
    CASE WHEN TRY_CAST(AMT_DOWN_PAYMENT AS DECIMAL(10,1)) < 0 THEN NULL
         ELSE TRY_CAST(AMT_DOWN_PAYMENT AS DECIMAL(10,1))
    END                                                                 AS amt_down_payment,
    TRY_CAST(AMT_GOODS_PRICE AS DECIMAL(10,1))                         AS amt_goods_price,
    WEEKDAY_APPR_PROCESS_START                                         AS weekday_appr_process_start,
    TRY_CAST(HOUR_APPR_PROCESS_START AS INT)                           AS hour_appr_process_start,
    FLAG_LAST_APPL_PER_CONTRACT                                        AS flag_last_appl_per_contract,
    TRY_CAST(TRY_CAST(NFLAG_LAST_APPL_IN_DAY AS FLOAT) AS INT)         AS nflag_last_appl_in_day,
    CASE WHEN TRY_CAST(RATE_DOWN_PAYMENT AS FLOAT) < 0 THEN NULL
         ELSE TRY_CAST(RATE_DOWN_PAYMENT AS FLOAT)
    END                                                                 AS rate_down_payment,
    TRY_CAST(RATE_INTEREST_PRIMARY AS FLOAT)                           AS rate_interest_primary,
    TRY_CAST(RATE_INTEREST_PRIVILEGED AS FLOAT)                        AS rate_interest_privileged,
    NAME_CASH_LOAN_PURPOSE                                             AS name_cash_loan_purpose,
    NAME_CONTRACT_STATUS                                               AS name_contract_status,
    TRY_CAST(DAYS_DECISION AS INT)                                     AS days_decision,
    NAME_PAYMENT_TYPE                                                  AS name_payment_type,
    CASE WHEN CODE_REJECT_REASON = 'XNA' THEN NULL ELSE CODE_REJECT_REASON END
                                                                        AS code_reject_reason,
    NAME_TYPE_SUITE                                                    AS name_type_suite,
    NAME_CLIENT_TYPE                                                   AS name_client_type,
    NAME_GOODS_CATEGORY                                                AS name_goods_category,
    NAME_PORTFOLIO                                                     AS name_portfolio,
    NAME_PRODUCT_TYPE                                                  AS name_product_type,
    CHANNEL_TYPE                                                       AS channel_type,
    TRY_CAST(SELLERPLACE_AREA AS INT)                                  AS sellerplace_area,
    NAME_SELLER_INDUSTRY                                               AS name_seller_industry,
    TRY_CAST(TRY_CAST(CNT_PAYMENT AS FLOAT) AS INT)                    AS cnt_payment,
    NAME_YIELD_GROUP                                                   AS name_yield_group,
    PRODUCT_COMBINATION                                                AS product_combination,
    CASE WHEN TRY_CAST(TRY_CAST(DAYS_FIRST_DRAWING AS FLOAT) AS INT) = 365243 THEN NULL
         ELSE TRY_CAST(TRY_CAST(DAYS_FIRST_DRAWING AS FLOAT) AS INT)
    END                                                                 AS days_first_drawing,
    CASE WHEN TRY_CAST(TRY_CAST(DAYS_FIRST_DUE AS FLOAT) AS INT) = 365243 THEN NULL
         ELSE TRY_CAST(TRY_CAST(DAYS_FIRST_DUE AS FLOAT) AS INT)
    END                                                                 AS days_first_due,
    CASE WHEN TRY_CAST(TRY_CAST(DAYS_LAST_DUE_1ST_VERSION AS FLOAT) AS INT) = 365243 THEN NULL
         ELSE TRY_CAST(TRY_CAST(DAYS_LAST_DUE_1ST_VERSION AS FLOAT) AS INT)
    END                                                                 AS days_last_due_1st_version,
    CASE WHEN TRY_CAST(TRY_CAST(DAYS_LAST_DUE AS FLOAT) AS INT) = 365243 THEN NULL
         ELSE TRY_CAST(TRY_CAST(DAYS_LAST_DUE AS FLOAT) AS INT)
    END                                                                 AS days_last_due,
    CASE WHEN TRY_CAST(TRY_CAST(DAYS_TERMINATION AS FLOAT) AS INT) = 365243 THEN NULL
         ELSE TRY_CAST(TRY_CAST(DAYS_TERMINATION AS FLOAT) AS INT)
    END                                                                 AS days_termination,
    TRY_CAST(TRY_CAST(NFLAG_INSURED_ON_APPROVAL AS FLOAT) AS INT)      AS nflag_insured_on_approval
FROM bronze.previous_application;
GO

-- Verifica: il conteggio deve tornare ~1.670.214
SELECT COUNT(*) AS righe_caricate FROM silver.previous_application;
GO
