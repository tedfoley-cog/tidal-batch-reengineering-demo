//ACCTEXTR JOB (ACME,FIN),'DAILY ACCT EXTRACT',
//         CLASS=A,MSGCLASS=X,MSGLEVEL=(1,1),
//         NOTIFY=&SYSUID,REGION=0M
//*
//*================================================================*
//* ACCTEXTR - DAILY ACCOUNT TRANSACTION EXTRACT                    *
//*                                                                 *
//* EXTRACTS PREVIOUS DAY'S TRANSACTIONS FROM DB2 ACCTDB TO        *
//* SEQUENTIAL DATASET FOR GL POSTING AND REPORTING.                *
//*                                                                 *
//* TIDAL JOB: ACCT_DAILY_EXTRACT (ID 1001)                         *
//* SCHEDULE:  WEEKDAY_BUSINESS, 02:00-05:00                        *
//* DEPENDENCIES: NONE (FIRST JOB IN FINANCE DAILY CHAIN)           *
//*================================================================*
//*
//*----------------------------------------------------------------*
//* STEP 1: EXECUTE ACCOUNT EXTRACT PROGRAM                         *
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
//*  OUTPUT EXTRACT FILE
//EXTOUT   DD  DSN=ACME.ACCT.EXTRACT.D&LYYMMDD,
//         DISP=(NEW,CATLG,DELETE),
//         SPACE=(CYL,(50,20)),
//         DCB=(RECFM=FB,LRECL=150,BLKSIZE=27000)
//*
//SYSTSIN  DD  *
 RUN PROGRAM(ACCTEXTRACT) PLAN(ACCTPLAN) -
     PARM('EXTRACT_DATE=&LYYMMDD')
/*
//*
//*----------------------------------------------------------------*
//* STEP 2: VERIFY EXTRACT RECORD COUNT                             *
//*----------------------------------------------------------------*
//VERIFY   EXEC PGM=IDCAMS,COND=(4,LT)
//SYSPRINT DD  SYSOUT=*
//INPUT    DD  DSN=ACME.ACCT.EXTRACT.D&LYYMMDD,DISP=SHR
//SYSIN    DD  *
 PRINT INFILE(INPUT) COUNT(1) -
       CHARACTER
/*
//*
