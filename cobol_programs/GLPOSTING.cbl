       IDENTIFICATION DIVISION.
       PROGRAM-ID. GLPOSTING.
      *================================================================*
      * GLPOSTING - GENERAL LEDGER POSTING PROGRAM                     *
      *                                                                *
      * READS VALIDATED ACCOUNT EXTRACT FILE AND POSTS TRANSACTIONS    *
      * TO THE GENERAL LEDGER MASTER FILE. APPLIES DOUBLE-ENTRY        *
      * BOOKKEEPING RULES: EACH TRANSACTION GENERATES A DEBIT TO      *
      * THE TARGET GL ACCOUNT AND A CORRESPONDING CREDIT TO THE        *
      * SOURCE ACCOUNT (OR VICE VERSA).                                *
      *                                                                *
      * INPUT:  SEQUENTIAL FILE ACME.ACCT.EXTRACT.Dyyyymmdd            *
      * OUTPUT: DB2 TABLE ACME.GL_MASTER (UPDATED)                     *
      *         DB2 TABLE ACME.GL_POSTING_LOG (INSERTED)               *
      *         POSTING REPORT ON SYSPRINT                             *
      *                                                                *
      * CALLED BY: JCL GLPOST.JCL VIA TIDAL JOB GL_POSTING_BATCH      *
      *                                                                *
      * RETURN CODES:                                                  *
      *   0  - SUCCESSFUL, ALL TRANSACTIONS POSTED                     *
      *   4  - SUCCESSFUL WITH WARNINGS (SOME RECORDS SKIPPED)         *
      *   8  - PARTIAL FAILURE (POSTING ERRORS ENCOUNTERED)            *
      *   12 - COMPLETE FAILURE (FILE I/O ERROR)                       *
      *   16 - COMPLETE FAILURE (DB2 ERROR)                            *
      *================================================================*
      *
       ENVIRONMENT DIVISION.
       CONFIGURATION SECTION.
       SOURCE-COMPUTER. IBM-390.
       OBJECT-COMPUTER. IBM-390.
      *
       INPUT-OUTPUT SECTION.
       FILE-CONTROL.
           SELECT EXTRACT-INPUT
               ASSIGN TO EXTIN
               ORGANIZATION IS SEQUENTIAL
               FILE STATUS IS WS-INPUT-STATUS.
           SELECT POSTING-REPORT
               ASSIGN TO SYSPRINT
               FILE STATUS IS WS-RPT-STATUS.
      *
       DATA DIVISION.
       FILE SECTION.
      *
       FD  EXTRACT-INPUT
           RECORDING MODE IS F
           BLOCK CONTAINS 0 RECORDS.
       01  INPUT-RECORD.
           05  INP-ACCT-NUMBER         PIC X(10).
           05  INP-TRANS-DATE          PIC X(10).
           05  INP-TRANS-TYPE          PIC X(2).
               88  INP-DEBIT               VALUE 'DR'.
               88  INP-CREDIT              VALUE 'CR'.
           05  INP-AMOUNT              PIC S9(11)V99 COMP-3.
           05  INP-DESCRIPTION         PIC X(40).
           05  INP-COST-CENTER         PIC X(6).
           05  INP-GL-ACCOUNT          PIC X(10).
           05  INP-REFERENCE-NUM       PIC X(12).
           05  INP-BATCH-ID            PIC X(8).
           05  INP-USER-ID             PIC X(8).
           05  INP-TIMESTAMP           PIC X(26).
           05  FILLER                  PIC X(17).
      *
       FD  POSTING-REPORT
           RECORDING MODE IS F.
       01  REPORT-LINE                 PIC X(133).
      *
       WORKING-STORAGE SECTION.
      *
       01  WS-INPUT-STATUS             PIC XX.
       01  WS-RPT-STATUS               PIC XX.
      *
           EXEC SQL INCLUDE SQLCA END-EXEC.
      *
      *----------------------------------------------------------------*
      * GL MASTER UPDATE FIELDS                                        *
      *----------------------------------------------------------------*
       01  WS-GL-FIELDS.
           05  WS-GL-ACCT-NUM         PIC X(10).
           05  WS-GL-PERIOD           PIC X(6).
           05  WS-GL-CURR-BALANCE     PIC S9(15)V99.
           05  WS-GL-POST-AMOUNT      PIC S9(11)V99.
      *
      *----------------------------------------------------------------*
      * POSTING LOG FIELDS                                             *
      *----------------------------------------------------------------*
       01  WS-LOG-FIELDS.
           05  WS-LOG-SEQ             PIC 9(9) VALUE 0.
           05  WS-LOG-GL-ACCT         PIC X(10).
           05  WS-LOG-TRANS-DATE      PIC X(10).
           05  WS-LOG-AMOUNT          PIC S9(11)V99.
           05  WS-LOG-TYPE            PIC X(2).
           05  WS-LOG-REF             PIC X(12).
           05  WS-LOG-BATCH           PIC X(8).
      *
      *----------------------------------------------------------------*
      * COUNTERS                                                       *
      *----------------------------------------------------------------*
       01  WS-COUNTERS.
           05  WS-RECORDS-READ        PIC 9(9) VALUE 0.
           05  WS-RECORDS-POSTED      PIC 9(9) VALUE 0.
           05  WS-RECORDS-SKIPPED     PIC 9(9) VALUE 0.
           05  WS-RECORDS-ERROR       PIC 9(9) VALUE 0.
           05  WS-TOTAL-DEBITS        PIC S9(15)V99 VALUE 0.
           05  WS-TOTAL-CREDITS       PIC S9(15)V99 VALUE 0.
      *
       01  WS-EOF-FLAG                PIC X VALUE 'N'.
           88  WS-EOF                         VALUE 'Y'.
       01  WS-RETURN-CODE             PIC S9(4) COMP VALUE 0.
       01  WS-POSTING-PERIOD          PIC X(6).
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
           ACCEPT WS-POSTING-PERIOD
               FROM ENVIRONMENT 'GL_PERIOD'
      *
           OPEN INPUT EXTRACT-INPUT
           IF WS-INPUT-STATUS NOT = '00'
               DISPLAY 'GLPOSTING: ERROR OPENING INPUT: '
                   WS-INPUT-STATUS
               MOVE 12 TO WS-RETURN-CODE
               STOP RUN
           END-IF
      *
           OPEN OUTPUT POSTING-REPORT
           DISPLAY 'GLPOSTING: STARTED FOR PERIOD ' WS-POSTING-PERIOD.
      *
       2000-PROCESS-RECORDS.
           READ EXTRACT-INPUT
               AT END SET WS-EOF TO TRUE
               NOT AT END
                   ADD 1 TO WS-RECORDS-READ
                   PERFORM 2100-VALIDATE-RECORD
           END-READ.
      *
       2100-VALIDATE-RECORD.
           IF INP-GL-ACCOUNT = SPACES
               ADD 1 TO WS-RECORDS-SKIPPED
               DISPLAY 'GLPOSTING: SKIPPED - NO GL ACCT: '
                   INP-REFERENCE-NUM
           ELSE
               PERFORM 2200-POST-TO-GL
           END-IF.
      *
       2200-POST-TO-GL.
           MOVE INP-GL-ACCOUNT TO WS-GL-ACCT-NUM
           MOVE WS-POSTING-PERIOD TO WS-GL-PERIOD
      *
           EXEC SQL
               SELECT CURRENT_BALANCE
               INTO   :WS-GL-CURR-BALANCE
               FROM   ACME.GL_MASTER
               WHERE  GL_ACCOUNT = :WS-GL-ACCT-NUM
               AND    GL_PERIOD  = :WS-GL-PERIOD
           END-EXEC
      *
           IF SQLCODE = 0
               MOVE INP-AMOUNT TO WS-GL-POST-AMOUNT
               IF INP-DEBIT
                   ADD WS-GL-POST-AMOUNT TO WS-GL-CURR-BALANCE
                   ADD WS-GL-POST-AMOUNT TO WS-TOTAL-DEBITS
               ELSE
                   SUBTRACT WS-GL-POST-AMOUNT
                       FROM WS-GL-CURR-BALANCE
                   ADD WS-GL-POST-AMOUNT TO WS-TOTAL-CREDITS
               END-IF
      *
               EXEC SQL
                   UPDATE ACME.GL_MASTER
                   SET    CURRENT_BALANCE = :WS-GL-CURR-BALANCE,
                          LAST_POST_DATE = CURRENT DATE,
                          POST_COUNT = POST_COUNT + 1
                   WHERE  GL_ACCOUNT = :WS-GL-ACCT-NUM
                   AND    GL_PERIOD  = :WS-GL-PERIOD
               END-EXEC
      *
               IF SQLCODE = 0
                   PERFORM 2300-LOG-POSTING
                   ADD 1 TO WS-RECORDS-POSTED
               ELSE
                   ADD 1 TO WS-RECORDS-ERROR
                   DISPLAY 'GLPOSTING: UPDATE ERROR SQLCODE='
                       SQLCODE ' GL=' WS-GL-ACCT-NUM
               END-IF
           ELSE IF SQLCODE = 100
               ADD 1 TO WS-RECORDS-SKIPPED
               DISPLAY 'GLPOSTING: GL ACCT NOT FOUND: '
                   WS-GL-ACCT-NUM
           ELSE
               ADD 1 TO WS-RECORDS-ERROR
               DISPLAY 'GLPOSTING: SELECT ERROR SQLCODE='
                   SQLCODE ' GL=' WS-GL-ACCT-NUM
           END-IF.
      *
       2300-LOG-POSTING.
           ADD 1 TO WS-LOG-SEQ
           MOVE INP-GL-ACCOUNT   TO WS-LOG-GL-ACCT
           MOVE INP-TRANS-DATE   TO WS-LOG-TRANS-DATE
           MOVE INP-AMOUNT       TO WS-LOG-AMOUNT
           MOVE INP-TRANS-TYPE   TO WS-LOG-TYPE
           MOVE INP-REFERENCE-NUM TO WS-LOG-REF
           MOVE INP-BATCH-ID     TO WS-LOG-BATCH
      *
           EXEC SQL
               INSERT INTO ACME.GL_POSTING_LOG
               (SEQ_NUM, GL_ACCOUNT, TRANS_DATE, POST_AMOUNT,
                TRANS_TYPE, REFERENCE_NUM, BATCH_ID, POST_TIMESTAMP)
               VALUES
               (:WS-LOG-SEQ, :WS-LOG-GL-ACCT, :WS-LOG-TRANS-DATE,
                :WS-LOG-AMOUNT, :WS-LOG-TYPE, :WS-LOG-REF,
                :WS-LOG-BATCH, CURRENT TIMESTAMP)
           END-EXEC.
      *
       3000-FINALIZE.
           EXEC SQL COMMIT END-EXEC
      *
           DISPLAY '================================================'
           DISPLAY 'GLPOSTING: POSTING COMPLETE'
           DISPLAY '  PERIOD:           ' WS-POSTING-PERIOD
           DISPLAY '  RECORDS READ:     ' WS-RECORDS-READ
           DISPLAY '  RECORDS POSTED:   ' WS-RECORDS-POSTED
           DISPLAY '  RECORDS SKIPPED:  ' WS-RECORDS-SKIPPED
           DISPLAY '  RECORDS IN ERROR: ' WS-RECORDS-ERROR
           DISPLAY '  TOTAL DEBITS:     ' WS-TOTAL-DEBITS
           DISPLAY '  TOTAL CREDITS:    ' WS-TOTAL-CREDITS
           DISPLAY '================================================'
      *
           IF WS-RECORDS-ERROR > 0
               MOVE 8 TO WS-RETURN-CODE
           ELSE IF WS-RECORDS-SKIPPED > 0
               MOVE 4 TO WS-RETURN-CODE
           END-IF
      *
           CLOSE EXTRACT-INPUT
           CLOSE POSTING-REPORT.
