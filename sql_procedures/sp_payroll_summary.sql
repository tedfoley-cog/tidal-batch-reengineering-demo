-- ============================================================
-- SP_PAYROLL_SUMMARY — Payroll Summary Statistics Procedure
--
-- Generates summary statistics after payroll calculation:
--   - Total gross pay, net pay, and deductions
--   - Breakdown by jurisdiction (federal, state)
--   - Employee count and average pay
--   - Writes results to PAYROLL_SUMMARY table
--
-- Called by Tidal job: SP_PAYROLL_SUMMARY (ID 2005)
-- Database: DB2 PAYROLLDB on z/OS
-- ============================================================

CREATE PROCEDURE ACME.SP_PAYROLL_SUMMARY (
    IN  P_PAY_PERIOD_END  DATE,
    OUT P_RETURN_CODE      INTEGER,
    OUT P_EMPLOYEE_COUNT   INTEGER,
    OUT P_TOTAL_GROSS      DECIMAL(13,2),
    OUT P_TOTAL_NET        DECIMAL(13,2)
)
LANGUAGE SQL
MODIFIES SQL DATA
BEGIN
    DECLARE V_TOTAL_FED_TAX    DECIMAL(13,2) DEFAULT 0;
    DECLARE V_TOTAL_STATE_TAX  DECIMAL(13,2) DEFAULT 0;
    DECLARE V_TOTAL_FICA       DECIMAL(13,2) DEFAULT 0;
    DECLARE V_TOTAL_MEDICARE   DECIMAL(13,2) DEFAULT 0;
    DECLARE V_TOTAL_401K       DECIMAL(13,2) DEFAULT 0;
    DECLARE V_TOTAL_HEALTH     DECIMAL(13,2) DEFAULT 0;

    -- --------------------------------------------------------
    -- Aggregate payroll results for the pay period
    -- --------------------------------------------------------
    SELECT COUNT(*),
           COALESCE(SUM(GROSS_PAY), 0),
           COALESCE(SUM(NET_PAY), 0),
           COALESCE(SUM(FED_TAX), 0),
           COALESCE(SUM(STATE_TAX), 0),
           COALESCE(SUM(FICA), 0),
           COALESCE(SUM(MEDICARE), 0),
           COALESCE(SUM(DEDUCT_401K), 0),
           COALESCE(SUM(DEDUCT_HEALTH), 0)
    INTO   P_EMPLOYEE_COUNT,
           P_TOTAL_GROSS,
           P_TOTAL_NET,
           V_TOTAL_FED_TAX,
           V_TOTAL_STATE_TAX,
           V_TOTAL_FICA,
           V_TOTAL_MEDICARE,
           V_TOTAL_401K,
           V_TOTAL_HEALTH
    FROM   ACME.PAYROLL_RESULTS
    WHERE  PAY_PERIOD_END = P_PAY_PERIOD_END;

    IF P_EMPLOYEE_COUNT = 0 THEN
        SET P_RETURN_CODE = 8;
        RETURN;
    END IF;

    -- --------------------------------------------------------
    -- Insert or update summary record
    -- --------------------------------------------------------
    MERGE INTO ACME.PAYROLL_SUMMARY AS T
    USING (VALUES (P_PAY_PERIOD_END)) AS S(PAY_PERIOD)
    ON T.PAY_PERIOD_END = S.PAY_PERIOD
    WHEN MATCHED THEN
        UPDATE SET
            EMPLOYEE_COUNT = P_EMPLOYEE_COUNT,
            TOTAL_GROSS    = P_TOTAL_GROSS,
            TOTAL_NET      = P_TOTAL_NET,
            TOTAL_FED_TAX  = V_TOTAL_FED_TAX,
            TOTAL_STATE_TAX = V_TOTAL_STATE_TAX,
            TOTAL_FICA     = V_TOTAL_FICA,
            TOTAL_MEDICARE = V_TOTAL_MEDICARE,
            TOTAL_401K     = V_TOTAL_401K,
            TOTAL_HEALTH   = V_TOTAL_HEALTH,
            SUMMARY_TIMESTAMP = CURRENT TIMESTAMP
    WHEN NOT MATCHED THEN
        INSERT (PAY_PERIOD_END, EMPLOYEE_COUNT, TOTAL_GROSS,
                TOTAL_NET, TOTAL_FED_TAX, TOTAL_STATE_TAX,
                TOTAL_FICA, TOTAL_MEDICARE, TOTAL_401K,
                TOTAL_HEALTH, SUMMARY_TIMESTAMP)
        VALUES (P_PAY_PERIOD_END, P_EMPLOYEE_COUNT, P_TOTAL_GROSS,
                P_TOTAL_NET, V_TOTAL_FED_TAX, V_TOTAL_STATE_TAX,
                V_TOTAL_FICA, V_TOTAL_MEDICARE, V_TOTAL_401K,
                V_TOTAL_HEALTH, CURRENT TIMESTAMP);

    SET P_RETURN_CODE = 0;

END;
