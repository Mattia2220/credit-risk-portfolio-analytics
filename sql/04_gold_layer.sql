-- ============================================================
-- 06 — GOLD LAYER — viste di aggregazione e scoring
-- Le viste su bureau/previous_application aggregano lo storico
-- (piu' righe per cliente) in una riga per cliente, PRIMA del
-- join a fact_application — e' il differenziatore tecnico del
-- progetto (vedi docs/2026-07-01-design-progetto.md).
-- ============================================================

USE credit_risk;
GO


-- ------------------------------------------------------------
-- gold.bureau_aggregato
-- Una riga per cliente, sintesi dello storico creditizio esterno.
-- ------------------------------------------------------------

DROP VIEW IF EXISTS gold.bureau_aggregato;
GO

CREATE VIEW gold.bureau_aggregato AS
SELECT
    sk_id_curr,
    COUNT(*)                                                          AS n_crediti_totali,
    SUM(CASE WHEN credit_active = 'Active' THEN 1 ELSE 0 END)         AS n_crediti_attivi,
    ISNULL(SUM(amt_credit_sum_debt), 0)                               AS debito_totale,
    MAX(credit_day_overdue)                                          AS ritardo_massimo,
    SUM(CASE WHEN credit_day_overdue > 0 THEN 1 ELSE 0 END)          AS n_crediti_in_ritardo,
    ISNULL(SUM(amt_credit_sum_overdue), 0)                            AS importo_scaduto_totale,
    SUM(cnt_credit_prolong)                                           AS n_prolungamenti_totali
FROM silver.bureau
GROUP BY sk_id_curr;
GO


-- ------------------------------------------------------------
-- gold.previous_application_aggregato
-- Una riga per cliente, sintesi dello storico di richieste
-- precedenti presso Home Credit.
--
-- NOTA: AVG(CASE WHEN condizione THEN colonna END) senza ELSE ->
-- le righe che non rispettano la condizione diventano NULL e
-- AVG le ignora automaticamente, quindi la media e' calcolata
-- solo sul sottoinsieme voluto (qui: prestiti approvati) senza
-- bisogno di un WHERE che scarterebbe l'intera riga.
-- giorni_ultima_richiesta usa MAX() non MIN(): days_decision e'
-- negativo, quindi il valore piu' vicino a zero (il massimo) e'
-- la richiesta piu' recente.
-- ------------------------------------------------------------

DROP VIEW IF EXISTS gold.previous_application_aggregato;
GO

CREATE VIEW gold.previous_application_aggregato AS
SELECT
    sk_id_curr,
    COUNT(*)                                                                          AS n_richieste_totali,
    CAST(SUM(CASE WHEN name_contract_status = 'Approved' THEN 1 ELSE 0 END) AS DECIMAL(10,2))
        / COUNT(*) * 100                                                             AS tasso_approvazione,
    SUM(CASE WHEN name_contract_status = 'Approved' AND days_termination IS NULL
             THEN 1 ELSE 0 END)                                                      AS n_prestiti_aperti,
    MAX(days_decision)                                                               AS giorni_ultima_richiesta,
    AVG(CASE WHEN name_contract_status = 'Approved' THEN amt_credit END)             AS importo_medio_concesso,
    AVG(CASE WHEN name_contract_status = 'Approved' THEN rate_interest_primary END)  AS tasso_interesse_medio,
    CAST(SUM(CASE WHEN nflag_insured_on_approval = 1 THEN 1 ELSE 0 END) AS DECIMAL(10,2))
        / NULLIF(SUM(CASE WHEN name_contract_status = 'Approved' THEN 1 ELSE 0 END), 0) * 100
                                                                                       AS quota_assicurati
FROM silver.previous_application
GROUP BY sk_id_curr;
GO


-- ------------------------------------------------------------
-- gold.dim_borrower_segment
-- Dimensione in stile star schema (chiave surrogata, 1 riga per
-- ogni combinazione UNICA di fascia eta'/reddito/istruzione/
-- abitazione) — non 1 riga per cliente. Creata PRIMA di
-- fact_application perche' quella vista la referenzia.
-- ------------------------------------------------------------

DROP VIEW IF EXISTS gold.dim_borrower_segment;
GO

CREATE VIEW gold.dim_borrower_segment AS
SELECT
    ROW_NUMBER() OVER (ORDER BY fascia_eta, fascia_reddito, name_education_type, name_housing_type) AS segment_id,
    fascia_eta,
    fascia_reddito,
    name_education_type,
    name_housing_type
FROM (
    SELECT DISTINCT fascia_eta, fascia_reddito, name_education_type, name_housing_type
    FROM silver.application
) AS combinazioni;
GO


-- ------------------------------------------------------------
-- gold.fact_application
-- Grain: 1 riga = 1 richiesta di prestito (come silver.application).
-- Unisce lo storico aggregato di bureau/previous_application con
-- LEFT JOIN (non tutte le richieste hanno storico: 85,7% ha
-- bureau, 94,6% ha previous_application — vedi Fase 1 QC).
--
-- COALESCE(..., 0) solo su conteggi/somme (uno "zero storico" ha
-- senso). Le medie/percentuali (tasso_approvazione, importo_medio_
-- concesso, tasso_interesse_medio, quota_assicurati,
-- giorni_ultima_richiesta) restano NULL se non c'e' storico:
-- uno zero forzato sarebbe fuorviante (es. tasso_approvazione=0%
-- implicherebbe "sempre rifiutato" invece di "mai valutato").
--
-- segment_id collega a gold.dim_borrower_segment: confronto
-- NULL-safe (ISNULL su entrambi i lati) perche' fascia_reddito
-- puo' essere NULL (l'unica riga con l'outlier di reddito messo
-- a NULL in Silver) e un normale '=' non farebbe mai match fra
-- due NULL.
-- ------------------------------------------------------------

DROP VIEW IF EXISTS gold.fact_application;
GO

CREATE VIEW gold.fact_application AS
SELECT
    a.*,
    seg.segment_id,
    COALESCE(b.n_crediti_totali, 0)        AS n_crediti_totali,
    COALESCE(b.n_crediti_attivi, 0)        AS n_crediti_attivi,
    COALESCE(b.debito_totale, 0)           AS debito_totale,
    COALESCE(b.ritardo_massimo, 0)         AS ritardo_massimo,
    COALESCE(b.n_crediti_in_ritardo, 0)    AS n_crediti_in_ritardo,
    COALESCE(b.importo_scaduto_totale, 0)  AS importo_scaduto_totale,
    COALESCE(b.n_prolungamenti_totali, 0)  AS n_prolungamenti_totali,
    COALESCE(p.n_richieste_totali, 0)      AS n_richieste_totali,
    p.tasso_approvazione,
    COALESCE(p.n_prestiti_aperti, 0)       AS n_prestiti_aperti,
    p.giorni_ultima_richiesta,
    p.importo_medio_concesso,
    p.tasso_interesse_medio,
    p.quota_assicurati
FROM silver.application a
LEFT JOIN gold.bureau_aggregato b               ON a.sk_id_curr = b.sk_id_curr
LEFT JOIN gold.previous_application_aggregato p ON a.sk_id_curr = p.sk_id_curr
LEFT JOIN gold.dim_borrower_segment seg
    ON  ISNULL(a.fascia_eta, '')          = ISNULL(seg.fascia_eta, '')
    AND ISNULL(a.fascia_reddito, '')      = ISNULL(seg.fascia_reddito, '')
    AND ISNULL(a.name_education_type, '') = ISNULL(seg.name_education_type, '')
    AND ISNULL(a.name_housing_type, '')   = ISNULL(seg.name_housing_type, '');
GO


-- ------------------------------------------------------------
-- gold.risk_scoring
-- Punteggio di rischio composito, a regole (no ML), e decile
-- NTILE(10) — decile 1 = piu' sicuro, decile 10 = piu' rischioso.
--
-- Costruzione (ogni pezzo validato confrontando il tasso di
-- default osservato per gruppo, non assunto a priori):
--   - punteggio_base_finale: media dei punteggi ext_source_1/2/3
--     disponibili (ignora i NULL). Per i 172 clienti senza
--     nessun punteggio (0,06%), fallback sulla media di
--     popolazione + penalita' dedicata (flag_no_ext_source).
--   - crediti in ritardo (bureau): forte gradiente osservato
--     (8%->64% di default da 0 a 4 crediti in ritardo), ma oltre
--     i 4 i gruppi sono troppo piccoli per fidarsi -> valore
--     usato con un tetto a 3 (MIN(n_crediti_in_ritardo,3)).
--   - tasso di approvazione storico basso: NTILE(10) sul tasso di
--     approvazione mostra un calo continuo fino al decile 6, poi
--     si appiattisce -> trattato come flag binario su decili 1-3
--     (worst 30%), non come valore continuo.
--   - fascia di reddito bassa: le fasce Basso/Medio-basso/Medio
--     hanno tasso di default simile fra loro (~8-8,6%) e
--     chiaramente piu' alto di Alto/Molto alto (~5,8-6,6%) ->
--     flag binario sulle prime 3 fasce.
--   - flag_pensionato: verificato che l'utente ha scelto di NON
--     includerlo come penalita' (direzione dell'effetto incerta,
--     non validata).
--   - n_prestiti_aperti: verificato ma escluso, effetto troppo
--     debole (7,9%->9,5% da 0 a 4 prestiti aperti) per giustificare
--     la complessita' aggiuntiva.
--
-- Punti di penalita' (dimensionati sull'intensita' dell'effetto
-- osservato, non arbitrari): crediti in ritardo -2 punti per
-- credito (fino a un tetto di -6), approvazione bassa -2,
-- reddito basso -1, nessun punteggio esterno -1.
-- Punteggio finale = punteggio_base_finale - (punti_penalita/100.0)
-- -- diviso 100.0 (non 100, altrimenti divisione fra interi
-- tronca a zero) per pesare la penalita' senza schiacciare il
-- punteggio base (che va da 0 a 1).
-- ------------------------------------------------------------

DROP VIEW IF EXISTS gold.risk_scoring;
GO

CREATE VIEW gold.risk_scoring AS
WITH punteggi_esterni AS (
    SELECT
        sk_id_curr,
        ISNULL(ext_source_1, 0) + ISNULL(ext_source_2, 0) + ISNULL(ext_source_3, 0) AS somma_punteggi,
        CASE WHEN ext_source_1 IS NOT NULL THEN 1 ELSE 0 END
      + CASE WHEN ext_source_2 IS NOT NULL THEN 1 ELSE 0 END
      + CASE WHEN ext_source_3 IS NOT NULL THEN 1 ELSE 0 END AS n_punteggi_disponibili
    FROM gold.fact_application
),
punteggio_grezzo AS (
    SELECT
        sk_id_curr,
        somma_punteggi / NULLIF(n_punteggi_disponibili, 0) AS punteggio_base
    FROM punteggi_esterni
),
punteggio_con_fallback AS (
    SELECT
        sk_id_curr,
        COALESCE(punteggio_base, AVG(punteggio_base) OVER ()) AS punteggio_base_finale,
        CASE WHEN punteggio_base IS NULL THEN 1 ELSE 0 END     AS flag_no_ext_source
    FROM punteggio_grezzo
),
decili_approvazione AS (
    SELECT
        sk_id_curr,
        CASE WHEN NTILE(10) OVER (ORDER BY tasso_approvazione) <= 3 THEN 1 ELSE 0 END AS flag_approvazione_bassa
    FROM gold.fact_application
    WHERE tasso_approvazione IS NOT NULL
),
punteggio_completo AS (
    SELECT
        f.sk_id_curr,
        f.target,
        pf.punteggio_base_finale,
        pf.flag_no_ext_source,
        CASE WHEN f.n_crediti_in_ritardo >= 3 THEN 3 ELSE f.n_crediti_in_ritardo END AS crediti_in_ritardo_capped,
        COALESCE(da.flag_approvazione_bassa, 0)                                     AS flag_approvazione_bassa,
        CASE WHEN f.fascia_reddito IN ('Basso', 'Medio-basso', 'Medio')
             THEN 1 ELSE 0 END                                                      AS flag_reddito_basso
    FROM gold.fact_application f
    JOIN punteggio_con_fallback pf ON f.sk_id_curr = pf.sk_id_curr
    LEFT JOIN decili_approvazione da ON f.sk_id_curr = da.sk_id_curr
)
SELECT
    sk_id_curr,
    target,
    punteggio_base_finale,
    flag_no_ext_source,
    crediti_in_ritardo_capped,
    flag_approvazione_bassa,
    flag_reddito_basso,
    (crediti_in_ritardo_capped * 2)
        + (flag_approvazione_bassa * 2)
        + (flag_reddito_basso * 1)
        + (flag_no_ext_source * 1)                                          AS punti_penalita_totali,
    punteggio_base_finale
        - ( ( (crediti_in_ritardo_capped * 2)
            + (flag_approvazione_bassa * 2)
            + (flag_reddito_basso * 1)
            + (flag_no_ext_source * 1) ) / 100.0 )                          AS punteggio_finale,
    NTILE(10) OVER (
        ORDER BY
            punteggio_base_finale
                - ( ( (crediti_in_ritardo_capped * 2)
                    + (flag_approvazione_bassa * 2)
                    + (flag_reddito_basso * 1)
                    + (flag_no_ext_source * 1) ) / 100.0 ) DESC
    )                                                                        AS decile_rischio
FROM punteggio_completo;
GO


-- ------------------------------------------------------------
-- gold.confronto_segmenti
-- Confronta il tasso di default fra fasce, una dimensione alla
-- volta (eta', reddito, istruzione), invece che sulla
-- combinazione completa di dim_borrower_segment: gruppi piu'
-- ampi e affidabili, coerente con l'approccio usato altrove nel
-- progetto (es. tetto sui crediti in ritardo).
--
-- UNION ALL impila i risultati delle 3 dimensioni con una
-- colonna tipo_segmento. RANK/PERCENT_RANK usano PARTITION BY
-- tipo_segmento cosi' la classifica riparte per ogni dimensione,
-- invece di mescolare es. una fascia d'eta' con un livello di
-- istruzione nella stessa classifica.
-- ------------------------------------------------------------

DROP VIEW IF EXISTS gold.confronto_segmenti;
GO

CREATE VIEW gold.confronto_segmenti AS
WITH segmenti_uniti AS (
    SELECT
        'Età' AS tipo_segmento,
        fascia_eta AS valore_segmento,
        COUNT(*) AS n_clienti,
        AVG(CAST(target AS DECIMAL(10,4))) AS tasso_default
    FROM gold.fact_application
    GROUP BY fascia_eta

    UNION ALL

    SELECT
        'Reddito',
        fascia_reddito,
        COUNT(*),
        AVG(CAST(target AS DECIMAL(10,4)))
    FROM gold.fact_application
    GROUP BY fascia_reddito

    UNION ALL

    SELECT
        'Istruzione',
        name_education_type,
        COUNT(*),
        AVG(CAST(target AS DECIMAL(10,4)))
    FROM gold.fact_application
    GROUP BY name_education_type
)
SELECT
    tipo_segmento,
    valore_segmento,
    n_clienti,
    tasso_default,
    RANK() OVER (PARTITION BY tipo_segmento ORDER BY tasso_default DESC)         AS rank_rischio,
    PERCENT_RANK() OVER (PARTITION BY tipo_segmento ORDER BY tasso_default DESC) AS percent_rank_rischio
FROM segmenti_uniti;
GO


-- ------------------------------------------------------------
-- gold.perdita_attesa
-- Perdita attesa per decile di rischio (tasso di default
-- osservato x esposizione), con simulazione soglia di
-- approvazione: totali progressivi (running total) che
-- rispondono a "se approvo tutti i clienti dal decile 1 fino a
-- questo incluso, quanta perdita attesa cumulata avrei".
--
-- Assunzione dichiarata: perdita attesa = tasso di default x
-- esposizione, cioe' si assume un tasso di recupero (LGD) pari
-- a zero in caso di default (nessun dato su garanzie/recupero
-- disponibile nello scope dati scelto per il progetto) —
-- semplificazione ragionevole per uno scoring a regole.
--
-- ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW dentro
-- OVER(ORDER BY decile_rischio): accumula dalla prima riga fino
-- a quella corrente, invece di una finestra fissa.
-- ------------------------------------------------------------

DROP VIEW IF EXISTS gold.perdita_attesa;
GO

CREATE VIEW gold.perdita_attesa AS
WITH per_decile AS (
    SELECT
        r.decile_rischio,
        COUNT(*) AS n_clienti,
        AVG(CAST(r.target AS DECIMAL(10,4))) AS tasso_default,
        SUM(f.amt_credit) AS esposizione_totale
    FROM gold.risk_scoring r
    JOIN gold.fact_application f ON r.sk_id_curr = f.sk_id_curr
    GROUP BY r.decile_rischio
),
perdita_per_decile AS (
    SELECT
        decile_rischio,
        n_clienti,
        tasso_default,
        esposizione_totale,
        tasso_default * esposizione_totale AS perdita_attesa_totale
    FROM per_decile
)
SELECT
    decile_rischio,
    n_clienti,
    tasso_default,
    esposizione_totale,
    perdita_attesa_totale,
    SUM(n_clienti) OVER (ORDER BY decile_rischio ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
        AS n_clienti_cumulato,
    SUM(esposizione_totale) OVER (ORDER BY decile_rischio ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
        AS esposizione_cumulata,
    SUM(perdita_attesa_totale) OVER (ORDER BY decile_rischio ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
        AS perdita_attesa_cumulata,
    SUM(perdita_attesa_totale) OVER (ORDER BY decile_rischio ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
        / SUM(esposizione_totale) OVER (ORDER BY decile_rischio ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
        AS tasso_perdita_cumulato
FROM perdita_per_decile;
GO

