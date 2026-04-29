       IDENTIFICATION DIVISION.
       PROGRAM-ID. PAYROLLCALC.
      *================================================================*
      * PAYROLLCALC - PAYROLL CALCULATION PROGRAM                      *
      *                                                                *
      * PROCESSES EMPLOYEE TIME RECORDS AND CALCULATES NET PAY.        *
      * APPLIES FEDERAL AND STATE TAX WITHHOLDING, BENEFIT             *
      * DEDUCTIONS, 401K CONTRIBUTIONS, AND GARNISHMENTS.              *
      *                                                                *
      * INPUT:  DB2 TABLE ACME.PAYROLL_TIME_STAGING                    *
      *         DB2 TABLE ACME.EMPLOYEE_MASTER                         *
      *         DB2 TABLE ACME.TAX_TABLES                              *
      *         DB2 TABLE ACME.BENEFIT_PLANS                           *
      * OUTPUT: DB2 TABLE ACME.PAYROLL_RESULTS                         *
      *         SEQUENTIAL FILE ACME.PAY.REGISTER.Dyyyymmdd            *
      *         PAYROLL REGISTER REPORT ON SYSPRINT                    *
      *                                                                *
      * CALLED BY: JCL PAYROLL.JCL VIA TIDAL JOB PAYROLL_CALC         *
      *================================================================*
      *
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-390.
       OBJECT-COMPUTER. IBM-390.
      *
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT PAY-REGISTER-FILE
               ASSIGN TO PAYREG
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-FILE-STATUS.
      *
       DATA DIVISION.
       FILE SECTION.
      *
       FD  PAY-REGISTER-FILE
           RECORDING MODE IS F
           BLOCK CONTAINS 0 RECORDS.
       01  PAY-REGISTER-RECORD.
           05  REG-EMPLOYEE-ID         PIC X(8).
           05  REG-EMPLOYEE-NAME       PIC X(30).
           05  REG-PAY-PERIOD          PIC X(10).
           05  REG-HOURS-REGULAR       PIC 9(3)V99.
           05  REG-HOURS-OVERTIME      PIC 9(3)V99.
           05  REG-GROSS-PAY           PIC S9(7)V99 COMP-3.
           05  REG-FED-TAX             PIC S9(7)V99 COMP-3.
           05  REG-STATE-TAX           PIC S9(7)V99 COMP-3.
           05  REG-FICA               PIC S9(7)V99 COMP-3.
           05  REG-MEDICARE            PIC S9(7)V99 COMP-3.
           05  REG-401K               PIC S9(7)V99 COMP-3.
           05  REG-HEALTH-INS          PIC S9(7)V99 COMP-3.
           05  REG-OTHER-DEDUCT        PIC S9(7)V99 COMP-3.
           05  REG-NET-PAY             PIC S9(7)V99 COMP-3.
           05  FILLER                  PIC X(10).
      *
       WORKING-STORAGE SECTION.
      *
       01  WS-FILE-STATUS              PIC XX.
      *
           EXEC SQL INCLUDE SQLCA END-EXEC.
      *
      *----------------------------------------------------------------*
      * EMPLOYEE PAY CALCULATION FIELDS                                *
      *----------------------------------------------------------------*
       01  WS-EMPLOYEE.
           05  WS-EMP-ID              PIC X(8).
           05  WS-EMP-NAME            PIC X(30).
           05  WS-EMP-STATE           PIC X(2).
           05  WS-EMP-FED-STATUS      PIC X(1).
               88  WS-SINGLE               VALUE 'S'.
               88  WS-MARRIED              VALUE 'M'.
           05  WS-EMP-EXEMPTIONS      PIC 9(2).
           05  WS-EMP-HOURLY-RATE     PIC S9(5)V99.
           05  WS-EMP-SALARY          PIC S9(7)V99.
           05  WS-EMP-PAY-TYPE        PIC X(1).
               88  WS-HOURLY               VALUE 'H'.
               88  WS-SALARIED             VALUE 'S'.
           05  WS-EMP-401K-PCT        PIC V99.
           05  WS-EMP-HEALTH-PLAN     PIC X(4).
      *
       01  WS-TIME-RECORD.
           05  WS-TIME-EMP-ID         PIC X(8).
           05  WS-TIME-HOURS-REG      PIC 9(3)V99.
           05  WS-TIME-HOURS-OT       PIC 9(3)V99.
      *
      *----------------------------------------------------------------*
      * CALCULATION WORK FIELDS                                        *
      *----------------------------------------------------------------*
       01  WS-CALC-FIELDS.
           05  WS-GROSS-PAY           PIC S9(7)V99 VALUE 0.
           05  WS-REG-PAY             PIC S9(7)V99 VALUE 0.
           05  WS-OT-PAY              PIC S9(7)V99 VALUE 0.
           05  WS-FED-TAX             PIC S9(7)V99 VALUE 0.
           05  WS-STATE-TAX           PIC S9(7)V99 VALUE 0.
           05  WS-FICA-TAX            PIC S9(7)V99 VALUE 0.
           05  WS-MEDICARE-TAX        PIC S9(7)V99 VALUE 0.
           05  WS-401K-DEDUCT         PIC S9(7)V99 VALUE 0.
           05  WS-HEALTH-DEDUCT       PIC S9(7)V99 VALUE 0.
           05  WS-OTHER-DEDUCT        PIC S9(7)V99 VALUE 0.
           05  WS-TOTAL-DEDUCTIONS    PIC S9(7)V99 VALUE 0.
           05  WS-NET-PAY             PIC S9(7)V99 VALUE 0.
      *
      *----------------------------------------------------------------*
      * TAX CONSTANTS (2026)                                           *
      *----------------------------------------------------------------*
       01  WS-TAX-RATES.
           05  WS-FICA-RATE           PIC V9999 VALUE .0620.
           05  WS-FICA-WAGE-BASE      PIC 9(7) VALUE 168600.
           05  WS-MEDICARE-RATE       PIC V9999 VALUE .0145.
           05  WS-OT-MULTIPLIER       PIC 9V99  VALUE 1.50.
      *
      *----------------------------------------------------------------*
      * SUMMARY ACCUMULATORS                                           *
      *----------------------------------------------------------------*
       01  WS-TOTALS.
           05  WS-TOT-EMPLOYEES       PIC 9(7) VALUE 0.
           05  WS-TOT-GROSS           PIC S9(11)V99 VALUE 0.
           05  WS-TOT-FED-TAX         PIC S9(11)V99 VALUE 0.
           05  WS-TOT-STATE-TAX       PIC S9(11)V99 VALUE 0.
           05  WS-TOT-FICA            PIC S9(11)V99 VALUE 0.
           05  WS-TOT-NET             PIC S9(11)V99 VALUE 0.
      *
       01  WS-PAY-PERIOD-END          PIC X(10).
       01  WS-RETURN-CODE             PIC S9(4) COMP VALUE 0.
       01  WS-EOF-FLAG                PIC X VALUE 'N'.
           88  WS-EOF                         VALUE 'Y'.
      *
      *----------------------------------------------------------------*
      * DB2 CURSOR: EMPLOYEES WITH TIME RECORDS THIS PERIOD            *
      *----------------------------------------------------------------*
           EXEC SQL DECLARE EMP_CURSOR CURSOR FOR
               SELECT T.EMPLOYEE_ID,
                      E.EMPLOYEE_NAME,
                      E.STATE_CODE,
                      E.FED_FILING_STATUS,
                      E.FED_EXEMPTIONS,
                      E.HOURLY_RATE,
                      E.ANNUAL_SALARY,
                      E.PAY_TYPE,
                      E.CONTRIB_401K_PCT,
                      E.HEALTH_PLAN_CODE,
                      T.HOURS_REGULAR,
                      T.HOURS_OVERTIME
               FROM   ACME.PAYROLL_TIME_STAGING T
               JOIN   ACME.EMPLOYEE_MASTER E
                   ON T.EMPLOYEE_ID = E.EMPLOYEE_ID
               WHERE  T.PAY_PERIOD_END = :WS-PAY-PERIOD-END
                 AND  E.STATUS = 'A'
               ORDER BY T.EMPLOYEE_ID
           END-EXEC.
      *
       PROCEDURE DIVISION.
      *
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PROCESS-EMPLOYEES
               UNTIL WS-EOF
           PERFORM 3000-FINALIZE
           MOVE WS-RETURN-CODE TO RETURN-CODE
           STOP RUN.
      *
       1000-INITIALIZE.
           ACCEPT WS-PAY-PERIOD-END
               FROM ENVIRONMENT 'PAY_PERIOD_END'
      *
           OPEN OUTPUT PAY-REGISTER-FILE
           IF WS-FILE-STATUS NOT = '00'
               DISPLAY 'PAYROLLCALC: ERROR OPENING REGISTER: '
                   WS-FILE-STATUS
               MOVE 12 TO WS-RETURN-CODE
               STOP RUN
           END-IF
      *
           EXEC SQL OPEN EMP_CURSOR END-EXEC
           IF SQLCODE NOT = 0
               DISPLAY 'PAYROLLCALC: CURSOR ERROR: SQLCODE='
                   SQLCODE
               MOVE 16 TO WS-RETURN-CODE
               STOP RUN
           END-IF
      *
           DISPLAY 'PAYROLLCALC: STARTED FOR PERIOD '
               WS-PAY-PERIOD-END.
      *
       2000-PROCESS-EMPLOYEES.
           EXEC SQL FETCH EMP_CURSOR INTO
               :WS-EMP-ID,
               :WS-EMP-NAME,
               :WS-EMP-STATE,
               :WS-EMP-FED-STATUS,
               :WS-EMP-EXEMPTIONS,
               :WS-EMP-HOURLY-RATE,
               :WS-EMP-SALARY,
               :WS-EMP-PAY-TYPE,
               :WS-EMP-401K-PCT,
               :WS-EMP-HEALTH-PLAN,
               :WS-TIME-HOURS-REG,
               :WS-TIME-HOURS-OT
           END-EXEC
      *
           EVALUATE SQLCODE
               WHEN 0
                   PERFORM 2100-CALCULATE-PAY
               WHEN 100
                   SET WS-EOF TO TRUE
               WHEN OTHER
                   DISPLAY 'PAYROLLCALC: FETCH ERROR: SQLCODE='
                       SQLCODE
                   MOVE 16 TO WS-RETURN-CODE
                   SET WS-EOF TO TRUE
           END-EVALUATE.
      *
       2100-CALCULATE-PAY.
           INITIALIZE WS-CALC-FIELDS
      *
           IF WS-HOURLY
               COMPUTE WS-REG-PAY =
                   WS-TIME-HOURS-REG * WS-EMP-HOURLY-RATE
               COMPUTE WS-OT-PAY =
                   WS-TIME-HOURS-OT * WS-EMP-HOURLY-RATE
                   * WS-OT-MULTIPLIER
               COMPUTE WS-GROSS-PAY = WS-REG-PAY + WS-OT-PAY
           ELSE
               COMPUTE WS-GROSS-PAY =
                   WS-EMP-SALARY / 26
           END-IF
      *
           PERFORM 2200-CALC-TAXES
           PERFORM 2300-CALC-DEDUCTIONS
      *
           COMPUTE WS-TOTAL-DEDUCTIONS =
               WS-FED-TAX + WS-STATE-TAX +
               WS-FICA-TAX + WS-MEDICARE-TAX +
               WS-401K-DEDUCT + WS-HEALTH-DEDUCT +
               WS-OTHER-DEDUCT
      *
           COMPUTE WS-NET-PAY =
               WS-GROSS-PAY - WS-TOTAL-DEDUCTIONS
      *
           PERFORM 2400-WRITE-RESULTS
      *
           ADD 1             TO WS-TOT-EMPLOYEES
           ADD WS-GROSS-PAY  TO WS-TOT-GROSS
           ADD WS-FED-TAX    TO WS-TOT-FED-TAX
           ADD WS-STATE-TAX  TO WS-TOT-STATE-TAX
           ADD WS-FICA-TAX   TO WS-TOT-FICA
           ADD WS-NET-PAY    TO WS-TOT-NET.
      *
       2200-CALC-TAXES.
           COMPUTE WS-FICA-TAX =
               WS-GROSS-PAY * WS-FICA-RATE
           COMPUTE WS-MEDICARE-TAX =
               WS-GROSS-PAY * WS-MEDICARE-RATE
      *
           EXEC SQL
               SELECT FED_RATE
               INTO   :WS-FED-TAX
               FROM   ACME.TAX_TABLES
               WHERE  TAX_TYPE = 'FED'
                 AND  FILING_STATUS = :WS-EMP-FED-STATUS
                 AND  :WS-GROSS-PAY BETWEEN LOW_BRACKET
                                        AND HIGH_BRACKET
           END-EXEC
           IF SQLCODE = 0
               COMPUTE WS-FED-TAX =
                   WS-GROSS-PAY * WS-FED-TAX
           END-IF
      *
           EXEC SQL
               SELECT STATE_RATE
               INTO   :WS-STATE-TAX
               FROM   ACME.TAX_TABLES
               WHERE  TAX_TYPE = 'STATE'
                 AND  STATE_CODE = :WS-EMP-STATE
                 AND  :WS-GROSS-PAY BETWEEN LOW_BRACKET
                                        AND HIGH_BRACKET
           END-EXEC
           IF SQLCODE = 0
               COMPUTE WS-STATE-TAX =
                   WS-GROSS-PAY * WS-STATE-TAX
           END-IF.
      *
       2300-CALC-DEDUCTIONS.
           COMPUTE WS-401K-DEDUCT =
               WS-GROSS-PAY * WS-EMP-401K-PCT
      *
           EXEC SQL
               SELECT BIWEEKLY_PREMIUM
               INTO   :WS-HEALTH-DEDUCT
               FROM   ACME.BENEFIT_PLANS
               WHERE  PLAN_CODE = :WS-EMP-HEALTH-PLAN
           END-EXEC
           IF SQLCODE NOT = 0
               MOVE 0 TO WS-HEALTH-DEDUCT
           END-IF.
      *
       2400-WRITE-RESULTS.
           MOVE WS-EMP-ID         TO REG-EMPLOYEE-ID
           MOVE WS-EMP-NAME       TO REG-EMPLOYEE-NAME
           MOVE WS-PAY-PERIOD-END TO REG-PAY-PERIOD
           MOVE WS-TIME-HOURS-REG TO REG-HOURS-REGULAR
           MOVE WS-TIME-HOURS-OT  TO REG-HOURS-OVERTIME
           MOVE WS-GROSS-PAY      TO REG-GROSS-PAY
           MOVE WS-FED-TAX        TO REG-FED-TAX
           MOVE WS-STATE-TAX      TO REG-STATE-TAX
           MOVE WS-FICA-TAX       TO REG-FICA
           MOVE WS-MEDICARE-TAX   TO REG-MEDICARE
           MOVE WS-401K-DEDUCT    TO REG-401K
           MOVE WS-HEALTH-DEDUCT  TO REG-HEALTH-INS
           MOVE WS-OTHER-DEDUCT   TO REG-OTHER-DEDUCT
           MOVE WS-NET-PAY        TO REG-NET-PAY
      *
           WRITE PAY-REGISTER-RECORD
      *
           EXEC SQL
               INSERT INTO ACME.PAYROLL_RESULTS
               (EMPLOYEE_ID, PAY_PERIOD_END, GROSS_PAY,
                FED_TAX, STATE_TAX, FICA, MEDICARE,
                DEDUCT_401K, DEDUCT_HEALTH, DEDUCT_OTHER,
                NET_PAY, CALC_TIMESTAMP)
               VALUES
               (:WS-EMP-ID, :WS-PAY-PERIOD-END, :WS-GROSS-PAY,
                :WS-FED-TAX, :WS-STATE-TAX, :WS-FICA-TAX,
                :WS-MEDICARE-TAX, :WS-401K-DEDUCT,
                :WS-HEALTH-DEDUCT, :WS-OTHER-DEDUCT,
                :WS-NET-PAY, CURRENT TIMESTAMP)
           END-EXEC.
      *
       3000-FINALIZE.
           EXEC SQL CLOSE EMP_CURSOR END-EXEC
           EXEC SQL COMMIT END-EXEC
      *
           DISPLAY '================================================'
           DISPLAY 'PAYROLLCALC: CALCULATION COMPLETE'
           DISPLAY '  PAY PERIOD:       ' WS-PAY-PERIOD-END
           DISPLAY '  EMPLOYEES:        ' WS-TOT-EMPLOYEES
           DISPLAY '  TOTAL GROSS:      ' WS-TOT-GROSS
           DISPLAY '  TOTAL FED TAX:    ' WS-TOT-FED-TAX
           DISPLAY '  TOTAL STATE TAX:  ' WS-TOT-STATE-TAX
           DISPLAY '  TOTAL FICA:       ' WS-TOT-FICA
           DISPLAY '  TOTAL NET PAY:    ' WS-TOT-NET
           DISPLAY '================================================'
      *
           CLOSE PAY-REGISTER-FILE.
