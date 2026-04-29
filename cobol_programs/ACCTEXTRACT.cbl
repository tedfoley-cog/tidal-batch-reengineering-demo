       IDENTIFICATION DIVISION.
       PROGRAM-ID. ACCTEXTRACT.
      *================================================================*
      * ACCTEXTRACT - DAILY ACCOUNT TRANSACTION EXTRACT PROGRAM        *
      *                                                                *
      * EXTRACTS ALL TRANSACTIONS FROM THE PREVIOUS BUSINESS DAY      *
      * FROM DB2 TABLE ACME.ACCT_TRANSACTIONS AND WRITES TO A         *
      * SEQUENTIAL FILE FOR DOWNSTREAM GL POSTING AND REPORTING.      *
      *                                                                *
      * INPUT:  DB2 TABLE ACME.ACCT_TRANSACTIONS (VIA CURSOR)         *
      * OUTPUT: SEQUENTIAL FILE ACME.ACCT.EXTRACT.Dyyyymmdd           *
      *         CONTROL REPORT ON SYSPRINT                            *
      *                                                                *
      * CALLED BY: JCL ACCTEXTR.JCL VIA TIDAL JOB ACCT_DAILY_EXTRACT *
      *================================================================*
      *
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-390.
       OBJECT-COMPUTER. IBM-390.
      *
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT EXTRACT-FILE
               ASSIGN TO EXTOUT
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-FILE-STATUS.
           SELECT CONTROL-REPORT
               ASSIGN TO SYSPRINT
               FILE STATUS IS WS-RPT-STATUS.
      *
       DATA DIVISION.
       FILE SECTION.
      *
       FD  EXTRACT-FILE
           RECORDING MODE IS F
           BLOCK CONTAINS 0 RECORDS.
       01  EXTRACT-RECORD.
           05  EXT-ACCT-NUMBER         PIC X(10).
           05  EXT-TRANS-DATE          PIC X(10).
           05  EXT-TRANS-TYPE          PIC X(2).
               88  EXT-DEBIT               VALUE 'DR'.
               88  EXT-CREDIT              VALUE 'CR'.
           05  EXT-AMOUNT              PIC S9(11)V99 COMP-3.
           05  EXT-DESCRIPTION         PIC X(40).
           05  EXT-COST-CENTER         PIC X(6).
           05  EXT-GL-ACCOUNT          PIC X(10).
           05  EXT-REFERENCE-NUM       PIC X(12).
           05  EXT-BATCH-ID            PIC X(8).
           05  EXT-USER-ID             PIC X(8).
           05  EXT-TIMESTAMP           PIC X(26).
           05  FILLER                  PIC X(17).
      *
       FD  CONTROL-REPORT
           RECORDING MODE IS F.
       01  REPORT-LINE                 PIC X(133).
      *
       WORKING-STORAGE SECTION.
      *
       01  WS-FILE-STATUS              PIC XX.
       01  WS-RPT-STATUS               PIC XX.
      *
      *----------------------------------------------------------------*
      * DB2 HOST VARIABLES                                             *
      *----------------------------------------------------------------*
       01  WS-DB2-FIELDS.
           05  WS-DB2-ACCT-NUM        PIC X(10).
           05  WS-DB2-TRANS-DATE      PIC X(10).
           05  WS-DB2-TRANS-TYPE      PIC X(2).
           05  WS-DB2-AMOUNT          PIC S9(11)V99.
           05  WS-DB2-DESC            PIC X(40).
           05  WS-DB2-COST-CTR        PIC X(6).
           05  WS-DB2-GL-ACCT         PIC X(10).
           05  WS-DB2-REF-NUM         PIC X(12).
           05  WS-DB2-BATCH-ID        PIC X(8).
           05  WS-DB2-USER-ID         PIC X(8).
           05  WS-DB2-TIMESTAMP       PIC X(26).
      *
      *----------------------------------------------------------------*
      * SQLCA AND SQL RETURN CODES                                     *
      *----------------------------------------------------------------*
           EXEC SQL INCLUDE SQLCA END-EXEC.
      *
       01  WS-SQLCODE                  PIC S9(9) COMP.
      *
      *----------------------------------------------------------------*
      * COUNTERS AND ACCUMULATORS                                      *
      *----------------------------------------------------------------*
       01  WS-COUNTERS.
           05  WS-RECORDS-READ        PIC 9(9)  VALUE 0.
           05  WS-RECORDS-WRITTEN     PIC 9(9)  VALUE 0.
           05  WS-DEBIT-COUNT         PIC 9(9)  VALUE 0.
           05  WS-CREDIT-COUNT        PIC 9(9)  VALUE 0.
           05  WS-DEBIT-TOTAL         PIC S9(13)V99 VALUE 0.
           05  WS-CREDIT-TOTAL        PIC S9(13)V99 VALUE 0.
           05  WS-NET-TOTAL           PIC S9(13)V99 VALUE 0.
      *
      *----------------------------------------------------------------*
      * DATE FIELDS                                                    *
      *----------------------------------------------------------------*
       01  WS-DATES.
           05  WS-CURRENT-DATE        PIC X(10).
           05  WS-EXTRACT-DATE        PIC X(10).
           05  WS-RUN-TIMESTAMP       PIC X(26).
      *
       01  WS-RETURN-CODE             PIC S9(4) COMP VALUE 0.
       01  WS-EOF-FLAG                PIC X     VALUE 'N'.
           88  WS-EOF                          VALUE 'Y'.
      *
      *----------------------------------------------------------------*
      * DB2 CURSOR DECLARATION                                         *
      *----------------------------------------------------------------*
           EXEC SQL DECLARE ACCT_CURSOR CURSOR FOR
               SELECT ACCT_NUMBER,
                      CHAR(TRANS_DATE, ISO),
                      TRANS_TYPE,
                      TRANS_AMOUNT,
                      TRANS_DESC,
                      COST_CENTER,
                      GL_ACCOUNT,
                      REFERENCE_NUM,
                      BATCH_ID,
                      USER_ID,
                      CHAR(ENTRY_TIMESTAMP)
               FROM   ACME.ACCT_TRANSACTIONS
               WHERE  TRANS_DATE = :WS-EXTRACT-DATE
               ORDER BY ACCT_NUMBER, ENTRY_TIMESTAMP
           END-EXEC.
      *
       PROCEDURE DIVISION.
      *
       0000-MAIN-PROCESS.
           PERFORM 1000-INITIALIZE
           PERFORM 2000-PROCESS-RECORDS
               UNTIL WS-EOF
           PERFORM 3000-FINALIZE
           MOVE WS-RETURN-CODE TO RETURN-CODE
           STOP RUN.
      *
       1000-INITIALIZE.
           ACCEPT WS-CURRENT-DATE FROM DATE YYYYMMDD
           MOVE FUNCTION CURRENT-DATE TO WS-RUN-TIMESTAMP
           ACCEPT WS-EXTRACT-DATE FROM ENVIRONMENT 'EXTRACT_DATE'
      *
           OPEN OUTPUT EXTRACT-FILE
           IF WS-FILE-STATUS NOT = '00'
               DISPLAY 'ERROR OPENING EXTRACT FILE: ' WS-FILE-STATUS
               MOVE 12 TO WS-RETURN-CODE
               PERFORM 3000-FINALIZE
               STOP RUN
           END-IF
      *
           OPEN OUTPUT CONTROL-REPORT
      *
           EXEC SQL OPEN ACCT_CURSOR END-EXEC
           IF SQLCODE NOT = 0
               DISPLAY 'ERROR OPENING CURSOR: SQLCODE=' SQLCODE
               MOVE 16 TO WS-RETURN-CODE
               PERFORM 3000-FINALIZE
               STOP RUN
           END-IF
      *
           DISPLAY 'ACCTEXTRACT: STARTED FOR DATE ' WS-EXTRACT-DATE.
      *
       2000-PROCESS-RECORDS.
           EXEC SQL FETCH ACCT_CURSOR INTO
               :WS-DB2-ACCT-NUM,
               :WS-DB2-TRANS-DATE,
               :WS-DB2-TRANS-TYPE,
               :WS-DB2-AMOUNT,
               :WS-DB2-DESC,
               :WS-DB2-COST-CTR,
               :WS-DB2-GL-ACCT,
               :WS-DB2-REF-NUM,
               :WS-DB2-BATCH-ID,
               :WS-DB2-USER-ID,
               :WS-DB2-TIMESTAMP
           END-EXEC
      *
           EVALUATE SQLCODE
               WHEN 0
                   ADD 1 TO WS-RECORDS-READ
                   PERFORM 2100-WRITE-EXTRACT
               WHEN 100
                   SET WS-EOF TO TRUE
               WHEN OTHER
                   DISPLAY 'DB2 FETCH ERROR: SQLCODE=' SQLCODE
                   MOVE 16 TO WS-RETURN-CODE
                   SET WS-EOF TO TRUE
           END-EVALUATE.
      *
       2100-WRITE-EXTRACT.
           MOVE WS-DB2-ACCT-NUM    TO EXT-ACCT-NUMBER
           MOVE WS-DB2-TRANS-DATE  TO EXT-TRANS-DATE
           MOVE WS-DB2-TRANS-TYPE  TO EXT-TRANS-TYPE
           MOVE WS-DB2-AMOUNT      TO EXT-AMOUNT
           MOVE WS-DB2-DESC        TO EXT-DESCRIPTION
           MOVE WS-DB2-COST-CTR    TO EXT-COST-CENTER
           MOVE WS-DB2-GL-ACCT     TO EXT-GL-ACCOUNT
           MOVE WS-DB2-REF-NUM     TO EXT-REFERENCE-NUM
           MOVE WS-DB2-BATCH-ID    TO EXT-BATCH-ID
           MOVE WS-DB2-USER-ID     TO EXT-USER-ID
           MOVE WS-DB2-TIMESTAMP   TO EXT-TIMESTAMP
      *
           WRITE EXTRACT-RECORD
           ADD 1 TO WS-RECORDS-WRITTEN
      *
           IF EXT-DEBIT
               ADD 1 TO WS-DEBIT-COUNT
               ADD WS-DB2-AMOUNT TO WS-DEBIT-TOTAL
           ELSE
               ADD 1 TO WS-CREDIT-COUNT
               ADD WS-DB2-AMOUNT TO WS-CREDIT-TOTAL
           END-IF.
      *
       3000-FINALIZE.
           EXEC SQL CLOSE ACCT_CURSOR END-EXEC
      *
           COMPUTE WS-NET-TOTAL =
               WS-DEBIT-TOTAL - WS-CREDIT-TOTAL
      *
           DISPLAY '================================================'
           DISPLAY 'ACCTEXTRACT: EXTRACT COMPLETE'
           DISPLAY '  EXTRACT DATE:     ' WS-EXTRACT-DATE
           DISPLAY '  RECORDS READ:     ' WS-RECORDS-READ
           DISPLAY '  RECORDS WRITTEN:  ' WS-RECORDS-WRITTEN
           DISPLAY '  DEBIT COUNT:      ' WS-DEBIT-COUNT
           DISPLAY '  CREDIT COUNT:     ' WS-CREDIT-COUNT
           DISPLAY '  DEBIT TOTAL:      ' WS-DEBIT-TOTAL
           DISPLAY '  CREDIT TOTAL:     ' WS-CREDIT-TOTAL
           DISPLAY '  NET TOTAL:        ' WS-NET-TOTAL
           DISPLAY '================================================'
      *
           CLOSE EXTRACT-FILE
           CLOSE CONTROL-REPORT.
