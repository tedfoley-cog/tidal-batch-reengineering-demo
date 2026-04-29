//GLPOST   JOB (ACME,FIN),'GL POSTING BATCH',
//         CLASS=A,MSGCLASS=X,MSGLEVEL=(1,1),
//         NOTIFY=&SYSUID,REGION=0M
//*
//*================================================================*
//* GLPOST - GENERAL LEDGER POSTING JCL                             *
//*                                                                 *
//* POSTS VALIDATED ACCOUNT TRANSACTIONS TO THE GENERAL LEDGER.     *
//* READS FROM DAILY EXTRACT, UPDATES GL MASTER AND POSTING LOG.    *
//*                                                                 *
//* TIDAL JOB: GL_POSTING_BATCH (ID 1003)                            *
//* SCHEDULE:  WEEKDAY_BUSINESS                                      *
//* DEPENDENCIES: ACCT_VALIDATION, SP_GL_VALIDATION                  *
//*                                                                 *
//* RETURN CODES:                                                   *
//*   0  - ALL TRANSACTIONS POSTED SUCCESSFULLY                     *
//*   4  - POSTED WITH WARNINGS (SOME RECORDS SKIPPED)              *
//*   8  - PARTIAL FAILURE                                          *
//*   12 - FILE I/O FAILURE                                         *
//*   16 - DB2 FAILURE                                              *
//*================================================================*
//*
//*----------------------------------------------------------------*
//* STEP 1: GL POSTING                                              *
//*----------------------------------------------------------------*
//POSTING  EXEC PGM=IKJEFT01,DYNAMNBR=20,
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
//*  INPUT: VALIDATED EXTRACT FILE
//EXTIN    DD  DSN=ACME.ACCT.EXTRACT.D&LYYMMDD,DISP=SHR
//*
//SYSTSIN  DD  *
 RUN PROGRAM(GLPOSTING) PLAN(GLPLAN) -
     PARM('GL_PERIOD=&LYYMM,POSTING_MODE=FINAL')
/*
//*
//*----------------------------------------------------------------*
//* STEP 2: GENERATE POSTING SUMMARY REPORT                         *
//*----------------------------------------------------------------*
//REPORT   EXEC PGM=IKJEFT01,DYNAMNBR=20,COND=(8,LT),
//         PARM='DSN SYSTEM(DB2P)'
//*
//STEPLIB  DD  DSN=DB2.SDSNLOAD,DISP=SHR
//*
//SYSTSPRT DD  SYSOUT=*
//SYSPRINT DD  SYSOUT=*
//*
//SYSTSIN  DD  *
 RUN PROGRAM(DSNTEP2) PLAN(DSNTEP71) -
     LIB('ACME.FINANCE.DBRMLIB')
/*
//SYSIN    DD  *
 SELECT GL_ACCOUNT, COUNT(*) AS POST_COUNT,
        SUM(POST_AMOUNT) AS TOTAL_AMOUNT
 FROM   ACME.GL_POSTING_LOG
 WHERE  POST_TIMESTAMP >= CURRENT DATE
 GROUP BY GL_ACCOUNT
 ORDER BY GL_ACCOUNT;
/*
//*
