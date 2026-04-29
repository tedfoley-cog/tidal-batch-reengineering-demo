//EODRECON JOB (ACME,FIN),'EOD RECONCILIATION',
//         CLASS=A,MSGCLASS=X,MSGLEVEL=(1,1),
//         NOTIFY=&SYSUID,REGION=0M
//*
//*================================================================*
//* EODRECON - END-OF-DAY RECONCILIATION JCL                        *
//*                                                                 *
//* RECONCILES ALL SUB-LEDGER POSTINGS AGAINST GL CONTROL TOTALS.   *
//* GENERATES EXCEPTION REPORT FOR OUT-OF-BALANCE CONDITIONS.       *
//* THIS JOB GATES THE MONTH-END CLOSE PROCESS.                     *
//*                                                                 *
//* TIDAL JOB: EOD_RECONCILIATION (ID 3001)                          *
//* SCHEDULE:  WEEKDAY_BUSINESS, 22:00-02:00                         *
//* DEPENDENCIES: GL_POSTING_BATCH, JOB_X47B                         *
//*                                                                 *
//* NOTE: JOB_X47B IS AN UNDOCUMENTED LEGACY DEPENDENCY.            *
//*       PURPOSE UNCLEAR. SEE TICKET INC01234567.                  *
//*================================================================*
//*
//*----------------------------------------------------------------*
//* STEP 1: EXTRACT SUB-LEDGER CONTROL TOTALS                       *
//*----------------------------------------------------------------*
//EXTRACT  EXEC PGM=IKJEFT01,DYNAMNBR=20,
//         PARM='DSN SYSTEM(DB2P)'
//*
//STEPLIB  DD  DSN=DB2.SDSNLOAD,DISP=SHR
//         DD  DSN=ACME.FINANCE.LOADLIB,DISP=SHR
//*
//DBRMLIB  DD  DSN=ACME.FINANCE.DBRMLIB,DISP=SHR
//*
//SYSTSPRT DD  SYSOUT=*
//SYSPRINT DD  SYSOUT=*
//SYSUDUMP DD  SYSOUT=*
//*
//*  WORK FILE FOR CONTROL TOTALS
//CTLTOTLS DD  DSN=&&CTLTOTALS,
//         DISP=(NEW,PASS),
//         SPACE=(CYL,(5,2)),
//         DCB=(RECFM=FB,LRECL=80,BLKSIZE=27920)
//*
//SYSTSIN  DD  *
 RUN PROGRAM(DSNTEP2) PLAN(DSNTEP71) -
     LIB('ACME.FINANCE.DBRMLIB')
/*
//SYSIN    DD  *
 SELECT 'GL' AS SOURCE,
        GL_ACCOUNT,
        SUM(CURRENT_BALANCE) AS TOTAL
 FROM   ACME.GL_MASTER
 WHERE  GL_PERIOD = CHAR(YEAR(CURRENT DATE))
                  || RIGHT('0' || CHAR(MONTH(CURRENT DATE)),2)
 GROUP BY GL_ACCOUNT
 UNION ALL
 SELECT 'AP' AS SOURCE,
        GL_ACCOUNT,
        SUM(INVOICE_AMOUNT) AS TOTAL
 FROM   ACME.AP_SUBLEDGER
 WHERE  POST_DATE = CURRENT DATE
 GROUP BY GL_ACCOUNT
 UNION ALL
 SELECT 'AR' AS SOURCE,
        GL_ACCOUNT,
        SUM(RECEIPT_AMOUNT) AS TOTAL
 FROM   ACME.AR_SUBLEDGER
 WHERE  POST_DATE = CURRENT DATE
 GROUP BY GL_ACCOUNT
 ORDER BY GL_ACCOUNT, SOURCE;
/*
//*
//*----------------------------------------------------------------*
//* STEP 2: COMPARE AND GENERATE EXCEPTION REPORT                   *
//*----------------------------------------------------------------*
//COMPARE  EXEC PGM=SORT,COND=(4,LT)
//*
//SORTIN   DD  DSN=&&CTLTOTALS,DISP=(OLD,DELETE)
//SORTOUT  DD  SYSOUT=*
//SYSOUT   DD  SYSOUT=*
//SYSIN    DD  *
 SORT FIELDS=(1,10,CH,A)
 OUTFIL REMOVECC,
        HEADER1='EOD RECONCILIATION REPORT',
        HEADER2='DATE: &DATE  TIME: &TIME',
        HEADER2='GL ACCT    SOURCE  AMOUNT'
/*
//*
