CREATE OR REPLACE PACKAGE LOAN.dpk_loan_BB_RPT
IS
   TYPE "LARGE_LOAN_RPT" IS RECORD
   (
      AC_ID                     NUMBER,
      Name_of_FI                VARCHAR2 (500),
      Name_of_group             VARCHAR2 (500),
      AC_TITLE                  VARCHAR2 (500),
      Ac_NO                     VARCHAR2 (500),
      sanction_date             DATE,
      sanction_amount           NUMBER,
      reschedule_date           DATE,
      reschedule_stage          NUMBER,
      reschedule_amount         NUMBER,
      date_of_expiry            DATE,                                   ----10
      amt_os_funded             NUMBER,
      amt_os_non_funded         NUMBER,
      credit_non_funded         NUMBER,
      total_exposure            NUMBER,
      total_exposure_of_group   NUMBER,
      fi_equity                 NUMBER,                                  ---16
      total_portfolio           NUMBER,
      Per_of_group_on_fi_eqt    NUMBER,
      Per_of_group_on_fi_port   NUMBER,
      cl_status                 VARCHAR2 (5),
      crg_score                 NUMBER,
      int_rate                  NUMBER,
      details_of_security       VARCHAR2 (500),
      value_of_security         NUMBER,
      business_add              VARCHAR2 (500),                          ---25
      fac_add                   VARCHAR2 (500),
      nature_of_ownership       VARCHAR2 (100),
      type_of_sector            VARCHAR2 (100),
      nature_of_business        VARCHAR2 (100),
      net_worth_borrower        VARCHAR2 (2024),                         ---30
      purpose_of_loan           VARCHAR2 (500),
      owner_deatils             VARCHAR2 (2024),
      director_of_any_Banking   VARCHAR2 (2024),
      bb_ref                    VARCHAR2 (500),
      Remarks                   VARCHAR2 (500),
      include_flag              VARCHAR2(2)
   );

   TYPE "LARGE_LOAN_TBL_RPT" IS TABLE OF LARGE_LOAN_RPT;

   FUNCTION LOAN_LARGE_RPT (pValueDate IN DATE)
      RETURN LARGE_LOAN_TBL_RPT
      PIPELINED;
END;
/