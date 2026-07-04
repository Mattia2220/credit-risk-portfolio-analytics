-- ============================================================
-- 00 — DATABASE SETUP
-- Crea il database "credit_risk" e i tre schemi dell'architettura
-- Medallion: Bronze, Silver, Gold.
-- Eseguire una sola volta prima di qualsiasi altro script.
-- ============================================================

-- Crea il database se non esiste
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'credit_risk')
BEGIN
    CREATE DATABASE credit_risk;
END
GO

USE credit_risk;
GO

-- Schema Bronze: dati grezzi importati direttamente dai CSV
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'bronze')
    EXEC('CREATE SCHEMA bronze');
GO

-- Schema Silver: dati puliti, tipizzati e arricchiti
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'silver')
    EXEC('CREATE SCHEMA silver');
GO

-- Schema Gold: viste analitiche aggregate per Power BI
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'gold')
    EXEC('CREATE SCHEMA gold');
GO
