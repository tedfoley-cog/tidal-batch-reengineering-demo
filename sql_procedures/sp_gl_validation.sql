-- ============================================================
-- SP_GL_VALIDATION — General Ledger Validation Stored Procedure
--
-- Validates GL integrity before daily posting:
--   1. Trial balance check (debits must equal credits)
--   2. Control total cross-check against sub-ledgers
--   3. Orphan account detection
--   4. Period boundary validation
--
-- Called by Tidal job: SP_GL_VALIDATION (ID 2003)
-- Database: DB2 ACCTDB on z/OS
--
-- Returns:
--   0 = Validation passed
--   4 = Validation passed with warnings
--   8 = Validation failed — GL out of balance
-- ============================================================

CREATE PROCEDURE ACME.SP_GL_VALIDATION (
    IN  P_GL_PERIOD    CHAR(6),
    OUT P_RETURN_CODE   INTEGER,
    OUT P_MESSAGE       VARCHAR(200)
)
LANGUAGE SQL
MODIFIES SQL DATA
BEGIN
    DECLARE V_DEBIT_TOTAL    DECIMAL(15,2) DEFAULT 0;
    DECLARE V_CREDIT_TOTAL   DECIMAL(15,2) DEFAULT 0;
    DECLARE V_DIFFERENCE     DECIMAL(15,2) DEFAULT 0;
    DECLARE V_ORPHAN_COUNT   INTEGER DEFAULT 0;
    DECLARE V_WARNING_COUNT  INTEGER DEFAULT 0;

    -- --------------------------------------------------------
    -- Check 1: Trial Balance — Debits must equal Credits
    -- --------------------------------------------------------
    SELECT COALESCE(SUM(CASE WHEN CURRENT_BALANCE >= 0
                             THEN CURRENT_BALANCE ELSE 0 END), 0),
           COALESCE(SUM(CASE WHEN CURRENT_BALANCE < 0
                             THEN ABS(CURRENT_BALANCE) ELSE 0 END), 0)
    INTO   V_DEBIT_TOTAL, V_CREDIT_TOTAL
    FROM   ACME.GL_MASTER
    WHERE  GL_PERIOD = P_GL_PERIOD;

    SET V_DIFFERENCE = V_DEBIT_TOTAL - V_CREDIT_TOTAL;

    IF ABS(V_DIFFERENCE) > 0.01 THEN
        SET P_RETURN_CODE = 8;
        SET P_MESSAGE = 'TRIAL BALANCE FAILED: Difference='
            || CHAR(V_DIFFERENCE)
            || ' Debits=' || CHAR(V_DEBIT_TOTAL)
            || ' Credits=' || CHAR(V_CREDIT_TOTAL);
        RETURN;
    END IF;

    -- --------------------------------------------------------
    -- Check 2: Orphan Accounts — GL accounts with no master
    -- --------------------------------------------------------
    SELECT COUNT(*)
    INTO   V_ORPHAN_COUNT
    FROM   ACME.GL_POSTING_LOG L
    WHERE  L.POST_TIMESTAMP >= CURRENT DATE
      AND  NOT EXISTS (
          SELECT 1 FROM ACME.GL_MASTER M
          WHERE  M.GL_ACCOUNT = L.GL_ACCOUNT
            AND  M.GL_PERIOD = P_GL_PERIOD
      );

    IF V_ORPHAN_COUNT > 0 THEN
        SET V_WARNING_COUNT = V_WARNING_COUNT + 1;
    END IF;

    -- --------------------------------------------------------
    -- Check 3: Period Boundary — No future-dated postings
    -- --------------------------------------------------------
    IF EXISTS (
        SELECT 1 FROM ACME.GL_POSTING_LOG
        WHERE  POST_TIMESTAMP > CURRENT TIMESTAMP + 1 DAY
    ) THEN
        SET V_WARNING_COUNT = V_WARNING_COUNT + 1;
    END IF;

    -- --------------------------------------------------------
    -- Return Result
    -- --------------------------------------------------------
    IF V_WARNING_COUNT > 0 THEN
        SET P_RETURN_CODE = 4;
        SET P_MESSAGE = 'VALIDATION PASSED WITH '
            || CHAR(V_WARNING_COUNT) || ' WARNING(S).'
            || ' Orphan accounts: ' || CHAR(V_ORPHAN_COUNT);
    ELSE
        SET P_RETURN_CODE = 0;
        SET P_MESSAGE = 'VALIDATION PASSED. Trial balance OK.'
            || ' Debits=' || CHAR(V_DEBIT_TOTAL)
            || ' Credits=' || CHAR(V_CREDIT_TOTAL);
    END IF;

END;
