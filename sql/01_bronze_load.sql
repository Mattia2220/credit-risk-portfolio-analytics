-- ============================================================
-- 01 — BRONZE LAYER — Caricamento dati grezzi da CSV
-- Tutte le colonne sono NVARCHAR: nessuna tipizzazione a questo
-- livello, per evitare perdita/corruzione di dati durante il
-- caricamento (vedi nota sotto sul bug di locale con FLOAT).
-- La conversione ai tipi corretti avviene nel layer Silver.
-- Ogni tabella viene ricreata da zero ad ogni esecuzione.
-- ============================================================

USE credit_risk;
GO

-- ------------------------------------------------------------
-- bronze.application (da application_train.csv)
--
-- NOTA 1: la prima versione di questa tabella era stata caricata
-- con l'Import Flat File Wizard di SSMS, che ha inferito i tipi
-- automaticamente (FLOAT per le colonne decimali). Il wizard ha
-- corrotto i valori di EXT_SOURCE_2 e DAYS_REGISTRATION per un
-- conflitto di locale sul separatore decimale (il CSV usa il
-- punto, formato US) — es. EXT_SOURCE_2 min risultava
-- 203111956480 invece di un valore fra 0 e 1. Da qui la scelta
-- di caricare tutto come NVARCHAR ed evitare l'inferenza
-- automatica dei tipi in fase di ingestion.
--
-- NOTA 2: la colonna WALLSMATERIAL_MODE contiene valori come
-- "Stone, brick" — nel CSV la virgola interna e' protetta da
-- virgolette (quoting standard RFC4180). La BULK INSERT con solo
-- FIELDTERMINATOR=',' non gestisce le virgolette, quindi per
-- ~74.000 righe (24%) tutte le colonne DOPO WALLSMATERIAL_MODE
-- scivolavano di una posizione, corrompendo silenziosamente anche
-- le colonne AMT_REQ_CREDIT_BUREAU_*. Fix: FORMAT='CSV' e
-- FIELDQUOTE='"' (richiede SQL Server 2017+), che fa rispettare
-- il quoting durante il parsing.
-- ------------------------------------------------------------

DROP TABLE IF EXISTS bronze.application;
GO

CREATE TABLE bronze.application (
    SK_ID_CURR                                    NVARCHAR(100),
    TARGET                                        NVARCHAR(100),
    NAME_CONTRACT_TYPE                            NVARCHAR(100),
    CODE_GENDER                                   NVARCHAR(100),
    FLAG_OWN_CAR                                  NVARCHAR(100),
    FLAG_OWN_REALTY                               NVARCHAR(100),
    CNT_CHILDREN                                  NVARCHAR(100),
    AMT_INCOME_TOTAL                              NVARCHAR(100),
    AMT_CREDIT                                    NVARCHAR(100),
    AMT_ANNUITY                                   NVARCHAR(100),
    AMT_GOODS_PRICE                               NVARCHAR(100),
    NAME_TYPE_SUITE                               NVARCHAR(100),
    NAME_INCOME_TYPE                              NVARCHAR(100),
    NAME_EDUCATION_TYPE                           NVARCHAR(100),
    NAME_FAMILY_STATUS                            NVARCHAR(100),
    NAME_HOUSING_TYPE                             NVARCHAR(100),
    REGION_POPULATION_RELATIVE                    NVARCHAR(100),
    DAYS_BIRTH                                    NVARCHAR(100),
    DAYS_EMPLOYED                                 NVARCHAR(100),
    DAYS_REGISTRATION                             NVARCHAR(100),
    DAYS_ID_PUBLISH                               NVARCHAR(100),
    OWN_CAR_AGE                                   NVARCHAR(100),
    FLAG_MOBIL                                    NVARCHAR(100),
    FLAG_EMP_PHONE                                NVARCHAR(100),
    FLAG_WORK_PHONE                               NVARCHAR(100),
    FLAG_CONT_MOBILE                              NVARCHAR(100),
    FLAG_PHONE                                    NVARCHAR(100),
    FLAG_EMAIL                                    NVARCHAR(100),
    OCCUPATION_TYPE                               NVARCHAR(100),
    CNT_FAM_MEMBERS                               NVARCHAR(100),
    REGION_RATING_CLIENT                          NVARCHAR(100),
    REGION_RATING_CLIENT_W_CITY                   NVARCHAR(100),
    WEEKDAY_APPR_PROCESS_START                    NVARCHAR(100),
    HOUR_APPR_PROCESS_START                       NVARCHAR(100),
    REG_REGION_NOT_LIVE_REGION                    NVARCHAR(100),
    REG_REGION_NOT_WORK_REGION                    NVARCHAR(100),
    LIVE_REGION_NOT_WORK_REGION                   NVARCHAR(100),
    REG_CITY_NOT_LIVE_CITY                        NVARCHAR(100),
    REG_CITY_NOT_WORK_CITY                        NVARCHAR(100),
    LIVE_CITY_NOT_WORK_CITY                       NVARCHAR(100),
    ORGANIZATION_TYPE                             NVARCHAR(100),
    EXT_SOURCE_1                                  NVARCHAR(100),
    EXT_SOURCE_2                                  NVARCHAR(100),
    EXT_SOURCE_3                                  NVARCHAR(100),
    APARTMENTS_AVG                                NVARCHAR(100),
    BASEMENTAREA_AVG                              NVARCHAR(100),
    YEARS_BEGINEXPLUATATION_AVG                   NVARCHAR(100),
    YEARS_BUILD_AVG                               NVARCHAR(100),
    COMMONAREA_AVG                                NVARCHAR(100),
    ELEVATORS_AVG                                 NVARCHAR(100),
    ENTRANCES_AVG                                 NVARCHAR(100),
    FLOORSMAX_AVG                                 NVARCHAR(100),
    FLOORSMIN_AVG                                 NVARCHAR(100),
    LANDAREA_AVG                                  NVARCHAR(100),
    LIVINGAPARTMENTS_AVG                          NVARCHAR(100),
    LIVINGAREA_AVG                                NVARCHAR(100),
    NONLIVINGAPARTMENTS_AVG                       NVARCHAR(100),
    NONLIVINGAREA_AVG                             NVARCHAR(100),
    APARTMENTS_MODE                               NVARCHAR(100),
    BASEMENTAREA_MODE                             NVARCHAR(100),
    YEARS_BEGINEXPLUATATION_MODE                  NVARCHAR(100),
    YEARS_BUILD_MODE                              NVARCHAR(100),
    COMMONAREA_MODE                               NVARCHAR(100),
    ELEVATORS_MODE                                NVARCHAR(100),
    ENTRANCES_MODE                                NVARCHAR(100),
    FLOORSMAX_MODE                                NVARCHAR(100),
    FLOORSMIN_MODE                                NVARCHAR(100),
    LANDAREA_MODE                                 NVARCHAR(100),
    LIVINGAPARTMENTS_MODE                         NVARCHAR(100),
    LIVINGAREA_MODE                               NVARCHAR(100),
    NONLIVINGAPARTMENTS_MODE                      NVARCHAR(100),
    NONLIVINGAREA_MODE                            NVARCHAR(100),
    APARTMENTS_MEDI                               NVARCHAR(100),
    BASEMENTAREA_MEDI                             NVARCHAR(100),
    YEARS_BEGINEXPLUATATION_MEDI                  NVARCHAR(100),
    YEARS_BUILD_MEDI                              NVARCHAR(100),
    COMMONAREA_MEDI                               NVARCHAR(100),
    ELEVATORS_MEDI                                NVARCHAR(100),
    ENTRANCES_MEDI                                NVARCHAR(100),
    FLOORSMAX_MEDI                                NVARCHAR(100),
    FLOORSMIN_MEDI                                NVARCHAR(100),
    LANDAREA_MEDI                                 NVARCHAR(100),
    LIVINGAPARTMENTS_MEDI                         NVARCHAR(100),
    LIVINGAREA_MEDI                               NVARCHAR(100),
    NONLIVINGAPARTMENTS_MEDI                      NVARCHAR(100),
    NONLIVINGAREA_MEDI                            NVARCHAR(100),
    FONDKAPREMONT_MODE                            NVARCHAR(100),
    HOUSETYPE_MODE                                NVARCHAR(100),
    TOTALAREA_MODE                                NVARCHAR(100),
    WALLSMATERIAL_MODE                            NVARCHAR(100),
    EMERGENCYSTATE_MODE                           NVARCHAR(100),
    OBS_30_CNT_SOCIAL_CIRCLE                      NVARCHAR(100),
    DEF_30_CNT_SOCIAL_CIRCLE                      NVARCHAR(100),
    OBS_60_CNT_SOCIAL_CIRCLE                      NVARCHAR(100),
    DEF_60_CNT_SOCIAL_CIRCLE                      NVARCHAR(100),
    DAYS_LAST_PHONE_CHANGE                        NVARCHAR(100),
    FLAG_DOCUMENT_2                               NVARCHAR(100),
    FLAG_DOCUMENT_3                               NVARCHAR(100),
    FLAG_DOCUMENT_4                               NVARCHAR(100),
    FLAG_DOCUMENT_5                               NVARCHAR(100),
    FLAG_DOCUMENT_6                               NVARCHAR(100),
    FLAG_DOCUMENT_7                               NVARCHAR(100),
    FLAG_DOCUMENT_8                               NVARCHAR(100),
    FLAG_DOCUMENT_9                               NVARCHAR(100),
    FLAG_DOCUMENT_10                              NVARCHAR(100),
    FLAG_DOCUMENT_11                              NVARCHAR(100),
    FLAG_DOCUMENT_12                              NVARCHAR(100),
    FLAG_DOCUMENT_13                              NVARCHAR(100),
    FLAG_DOCUMENT_14                              NVARCHAR(100),
    FLAG_DOCUMENT_15                              NVARCHAR(100),
    FLAG_DOCUMENT_16                              NVARCHAR(100),
    FLAG_DOCUMENT_17                              NVARCHAR(100),
    FLAG_DOCUMENT_18                              NVARCHAR(100),
    FLAG_DOCUMENT_19                              NVARCHAR(100),
    FLAG_DOCUMENT_20                              NVARCHAR(100),
    FLAG_DOCUMENT_21                              NVARCHAR(100),
    AMT_REQ_CREDIT_BUREAU_HOUR                    NVARCHAR(100),
    AMT_REQ_CREDIT_BUREAU_DAY                     NVARCHAR(100),
    AMT_REQ_CREDIT_BUREAU_WEEK                    NVARCHAR(100),
    AMT_REQ_CREDIT_BUREAU_MON                     NVARCHAR(100),
    AMT_REQ_CREDIT_BUREAU_QRT                     NVARCHAR(100),
    AMT_REQ_CREDIT_BUREAU_YEAR                    NVARCHAR(100)
);
GO

BULK INSERT bronze.application
FROM 'C:\Users\matti\work\projects\portfolio-credit-risk\sources\application_train.csv'
WITH (FIRSTROW=2, FORMAT='CSV', FIELDQUOTE='"', FIELDTERMINATOR=',', ROWTERMINATOR='0x0a', TABLOCK);
GO

-- Verifica: il conteggio deve tornare 307511
SELECT COUNT(*) AS righe_caricate FROM bronze.application;
GO

-- ------------------------------------------------------------
-- bronze.bureau (da bureau.csv)
--
-- NOTA: import fallito col wizard su CREDIT_DAY_OVERDUE — il
-- wizard aveva inferito TINYINT (range 0-255) da un campione di
-- righe piccole, poi ha trovato 2603 nel file completo e si è
-- bloccato. Stesso motivo per cui tutto è NVARCHAR qui.
-- ------------------------------------------------------------

DROP TABLE IF EXISTS bronze.bureau;
GO

CREATE TABLE bronze.bureau (
    SK_ID_CURR                                    NVARCHAR(100),
    SK_ID_BUREAU                                  NVARCHAR(100),
    CREDIT_ACTIVE                                 NVARCHAR(100),
    CREDIT_CURRENCY                               NVARCHAR(100),
    DAYS_CREDIT                                   NVARCHAR(100),
    CREDIT_DAY_OVERDUE                            NVARCHAR(100),
    DAYS_CREDIT_ENDDATE                           NVARCHAR(100),
    DAYS_ENDDATE_FACT                             NVARCHAR(100),
    AMT_CREDIT_MAX_OVERDUE                        NVARCHAR(100),
    CNT_CREDIT_PROLONG                            NVARCHAR(100),
    AMT_CREDIT_SUM                                NVARCHAR(100),
    AMT_CREDIT_SUM_DEBT                           NVARCHAR(100),
    AMT_CREDIT_SUM_LIMIT                          NVARCHAR(100),
    AMT_CREDIT_SUM_OVERDUE                        NVARCHAR(100),
    CREDIT_TYPE                                   NVARCHAR(100),
    DAYS_CREDIT_UPDATE                            NVARCHAR(100),
    AMT_ANNUITY                                   NVARCHAR(100)
);
GO

BULK INSERT bronze.bureau
FROM 'C:\Users\matti\work\projects\portfolio-credit-risk\sources\bureau.csv'
WITH (FIRSTROW=2, FIELDTERMINATOR=',', ROWTERMINATOR='0x0a', TABLOCK);
GO

-- Verifica: il conteggio deve tornare ~1.716.428
SELECT COUNT(*) AS righe_caricate FROM bronze.bureau;
GO

-- ------------------------------------------------------------
-- bronze.previous_application (da previous_application.csv)
--
-- NOTA: stesso problema di quoting descritto sopra per
-- application_train.csv — qui la causa e' NAME_TYPE_SUITE con
-- valore "Spouse, partner" (67.069 occorrenze). Usa anch'esso
-- FORMAT='CSV' + FIELDQUOTE per evitare lo scivolamento colonne.
-- ------------------------------------------------------------

DROP TABLE IF EXISTS bronze.previous_application;
GO

CREATE TABLE bronze.previous_application (
    SK_ID_PREV                                    NVARCHAR(100),
    SK_ID_CURR                                    NVARCHAR(100),
    NAME_CONTRACT_TYPE                            NVARCHAR(100),
    AMT_ANNUITY                                    NVARCHAR(100),
    AMT_APPLICATION                                NVARCHAR(100),
    AMT_CREDIT                                     NVARCHAR(100),
    AMT_DOWN_PAYMENT                               NVARCHAR(100),
    AMT_GOODS_PRICE                                NVARCHAR(100),
    WEEKDAY_APPR_PROCESS_START                     NVARCHAR(100),
    HOUR_APPR_PROCESS_START                        NVARCHAR(100),
    FLAG_LAST_APPL_PER_CONTRACT                    NVARCHAR(100),
    NFLAG_LAST_APPL_IN_DAY                         NVARCHAR(100),
    RATE_DOWN_PAYMENT                              NVARCHAR(100),
    RATE_INTEREST_PRIMARY                          NVARCHAR(100),
    RATE_INTEREST_PRIVILEGED                       NVARCHAR(100),
    NAME_CASH_LOAN_PURPOSE                         NVARCHAR(100),
    NAME_CONTRACT_STATUS                           NVARCHAR(100),
    DAYS_DECISION                                  NVARCHAR(100),
    NAME_PAYMENT_TYPE                              NVARCHAR(100),
    CODE_REJECT_REASON                             NVARCHAR(100),
    NAME_TYPE_SUITE                                NVARCHAR(100),
    NAME_CLIENT_TYPE                               NVARCHAR(100),
    NAME_GOODS_CATEGORY                            NVARCHAR(100),
    NAME_PORTFOLIO                                 NVARCHAR(100),
    NAME_PRODUCT_TYPE                              NVARCHAR(100),
    CHANNEL_TYPE                                   NVARCHAR(100),
    SELLERPLACE_AREA                               NVARCHAR(100),
    NAME_SELLER_INDUSTRY                           NVARCHAR(100),
    CNT_PAYMENT                                    NVARCHAR(100),
    NAME_YIELD_GROUP                               NVARCHAR(100),
    PRODUCT_COMBINATION                            NVARCHAR(100),
    DAYS_FIRST_DRAWING                              NVARCHAR(100),
    DAYS_FIRST_DUE                                  NVARCHAR(100),
    DAYS_LAST_DUE_1ST_VERSION                       NVARCHAR(100),
    DAYS_LAST_DUE                                   NVARCHAR(100),
    DAYS_TERMINATION                                NVARCHAR(100),
    NFLAG_INSURED_ON_APPROVAL                       NVARCHAR(100)
);
GO

BULK INSERT bronze.previous_application
FROM 'C:\Users\matti\work\projects\portfolio-credit-risk\sources\previous_application.csv'
WITH (FIRSTROW=2, FORMAT='CSV', FIELDQUOTE='"', FIELDTERMINATOR=',', ROWTERMINATOR='0x0a', TABLOCK);
GO

-- Verifica: il conteggio deve tornare ~1.670.214
SELECT COUNT(*) AS righe_caricate FROM bronze.previous_application;
GO
