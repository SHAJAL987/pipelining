CREATE OR REPLACE PACKAGE BODY LOAN.dpk_loan_BB_RPT
IS
   FUNCTION LOAN_LARGE_RPT (pValueDate IN DATE)
      RETURN LARGE_LOAN_TBL_RPT
      PIPELINED
   IS
      vLoan_INFO        LARGE_LOAN_TBL_RPT;
      pdx               NUMBER := 0;
      vBankName         VARCHAR2 (250);
      vSanctionDate     DATE;
      vSanctionLimit    NUMBER;

      vIntrate          NUMBER;
      vLoanExpireDate   DATE;
      vFiEquity         NUMBER;
      vTotloan          NUMBER;

      vSecurityType     VARCHAR2 (1250);
      vSecurityAmt      NUMBER := 0;
      vTotal_eqty       NUMBER := 0;

      vRegAdd           VARCHAR2 (550);
      vFacAdd           VARCHAR2 (550);
      
      vOwnerDetails  VARCHAR2 (1550);


      vErrorMessage     VARCHAR2 (1024);
      vMyException      EXCEPTION;


      CURSOR c1
      IS
           SELECT group_cust_no,
                  AC_ID,
                  AC_NO,
                  old_ac_no,
                  cust_no,
                  AC_TITLE,
                  SANCTION_ID,
                  AC_TYPE_ID,
                  CL_STATUS,
                  os,
                  SUM (os)
                     OVER (PARTITION BY group_cust_no ORDER BY group_cust_no)
                     AS group_total,
                  group_flag
             FROM (  SELECT group_cust_no,
                            y.AC_ID,
                            AC_NO,
                            old_ac_no,
                            y.cust_no,
                            AC_TITLE,
                            Y.SANCTION_ID,
                            y.AC_TYPE_ID,
                            y.CL_STATUS,
                            SUM (
                                 DECODE (d.drcr_code, 'D', Tran_amt_lc, 0)
                               - DECODE (d.drcr_code, 'C', Tran_amt_lc, 0))
                               AS os,
                            'G' AS group_flag
                       FROM emob.MB_CUST_GROUP x,
                            emob.mb_account_mst Y,
                            EMOB.MB_TRANSACTION_DTL d
                      WHERE     GROUP_TYPE = 'GRC'
                            AND X.APPLICANT_CUST_NO = Y.CUST_NO
                            AND D.VALUE_DATE <= pValueDate
                            AND d.ac_id = y.ac_id
                   GROUP BY group_cust_no,
                            y.AC_ID,
                            AC_NO,
                            old_ac_no,
                            y.cust_no,
                            AC_TITLE,
                            Y.SANCTION_ID,
                            y.AC_TYPE_ID,
                            y.CL_STATUS
                   UNION ALL
                   SELECT group_cust_no,
                          AC_ID,
                          AC_NO,
                          old_ac_no,
                          cust_no,
                          AC_TITLE,
                          SANCTION_ID,
                          AC_TYPE_ID,
                          CL_STATUS,
                          os,
                          group_flag
                     FROM (  SELECT y.cust_no AS group_cust_no,
                                    y.AC_ID,
                                    AC_NO,
                                    old_ac_no,
                                    y.cust_no,
                                    AC_TITLE,
                                    Y.SANCTION_ID,
                                    y.AC_TYPE_ID,
                                    y.CL_STATUS,
                                    SUM (
                                         DECODE (d.drcr_code,
                                                 'D', Tran_amt_lc,
                                                 0)
                                       - DECODE (d.drcr_code,
                                                 'C', Tran_amt_lc,
                                                 0))
                                       AS os,
                                    'C' AS group_flag
                               FROM emob.mb_account_mst Y,
                                    EMOB.MB_TRANSACTION_DTL d,
                                    emob.mb_product_mst p
                              WHERE     d.ac_id = y.ac_id
                                    AND y.ac_type_id = p.ac_type_id
                                    AND P.ASST_LIB = 'A'
                                    AND D.VALUE_DATE <= pValueDate
                                    AND y.ac_status = 'ACT'
                                    AND Y.CUST_NO NOT IN
                                           (SELECT APPLICANT_CUST_NO
                                              FROM emob.MB_CUST_GROUP
                                             WHERE GROUP_TYPE = 'GRC')
                           GROUP BY y.cust_no,
                                    y.AC_ID,
                                    AC_NO,
                                    old_ac_no,
                                    AC_TITLE,
                                    Y.SANCTION_ID,
                                    y.AC_TYPE_ID,
                                    y.CL_STATUS
                           ORDER BY 10 DESC)
                    WHERE ROWNUM <= 15
                   ORDER BY 10 DESC)
         ORDER BY 11 DESC;

   BEGIN
      BEGIN
         SELECT BANK_NAME INTO vBankName FROM emob.MB_BANK_INFO;
      END;

      vLoan_INFO :=
         LARGE_LOAN_TBL_RPT (NULL,
                             NULL,
                             NULL,
                             NULL,
                             NULL,
                             NULL,
                             NULL,
                             NULL,
                             NULL,
                             NULL,                                        --10
                             NULL,
                             NULL,
                             NULL,
                             NULL,
                             NULL,
                             NULL,
                             NULL,
                             NULL,
                             NULL,
                             NULL,                                        --20
                             NULL,
                             NULL,
                             NULL,
                             NULL,
                             NULL,
                             NULL,
                             NULL,
                             NULL,
                             NULL,
                             NULL,                                        --30
                             NULL,
                             NULL,
                             NULL,
                             NULL,
                             NULL,                                      ----35
                             NULL,
                             NULL);


      FOR a IN c1
      LOOP
         pdx := pdx + 1;
         vLoan_INFO.EXTEND (1);
         vLoan_INFO (pdx).AC_ID := a.ac_id;
         vLoan_INFO (pdx).Name_of_FI := vBankName;



         vLoan_INFO (pdx).Name_of_group :=
            EMOB.PKG_GLOBAL_OBJECTS.GET_CUSTOMER_NAME (a.group_cust_no);
         vLoan_INFO (pdx).AC_TITLE := a.AC_TITLE;
         vLoan_INFO (pdx).Ac_NO := a.AC_NO;


         BEGIN
            SELECT SANCTION_DATE
              --, SANCTION_LIMIT
              INTO vSanctionDate
              --, vSanctionLimit
              FROM loan.LOAN_GLOBAL_LIMIT
             WHERE sanction_id = a.SANCTION_ID;
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               -- vSanctionLimit := 0;
               vSanctionDate := NULL;
            WHEN OTHERS
            THEN
               vSanctionLimit := 0;
         -- vSanctionDate := NULL;
         END;



         vLoan_INFO (pdx).sanction_date := vSanctionDate;



         BEGIN
            SELECT int_rate, EXPAIRY_DATE, LIMIT_AMT
              INTO vIntrate, vLoanExpireDate, vSanctionLimit
              FROM loan.mb_loan_int_mst
             WHERE ac_id = a.ac_id AND active_flag = 'Y';
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               vIntrate := 0;
               vLoanExpireDate := NULL;
               vSanctionLimit := 0;
            WHEN OTHERS
            THEN
               vIntrate := 0;
               vLoanExpireDate := NULL;
               vSanctionLimit := 0;
         END;


         vLoan_INFO (pdx).sanction_amount := vSanctionLimit;
         vLoan_INFO (pdx).int_rate := vIntrate;
         vLoan_INFO (pdx).date_of_expiry := vLoanExpireDate;

         vLoan_INFO (pdx).amt_os_funded := a.os;
         vLoan_INFO (pdx).amt_os_non_funded := 0;
         vLoan_INFO (pdx).credit_non_funded := 0;


         vLoan_INFO (pdx).total_exposure := a.os;
         vLoan_INFO (pdx).total_exposure_of_group := a.os;


         BEGIN
            SELECT SUM (CR_AMT_LC)
              INTO vFiEquity
              FROM emob.mb_glac_mst x, emob.mb_gl_summary y
             WHERE     PARENT_ID IN (70, 74, 84)
                   AND X.GLAC_ID = Y.GLAC_ID
                   AND Y.VALUE_DATE <= pValueDate;
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               vFiEquity := 0;
            WHEN OTHERS
            THEN
               vFiEquity := 0;
         END;

         vLoan_INFO (pdx).fi_equity := vFiEquity;


         BEGIN
            SELECT SUM (DR_AMT_LC) - SUM (CR_AMT_LC)
              INTO vTotloan
              FROM emob.mb_product_mst x, emob.mb_gl_summary y
             WHERE     X.TOTALING_GL_ACC = Y.GLAC_ID
                   AND X.ASST_LIB = 'A'
                   AND Y.VALUE_DATE <= pValueDate;
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               vTotloan := 0;
            WHEN OTHERS
            THEN
               vTotloan := 0;
         END;

         vLoan_INFO (pdx).total_portfolio := vTotloan;

         vLoan_INFO (pdx).Per_of_group_on_fi_eqt :=
            ROUND (a.os / vFiEquity, 2);

         vLoan_INFO (pdx).Per_of_group_on_fi_port :=
            ROUND (a.os / vTotloan, 2);



         vLoan_INFO (pdx).cl_status := a.CL_STATUS;


         BEGIN
            SELECT SUM (x.SECURITY_AMT),
                   LISTAGG (SECURITY_NAME, ',')
                      WITHIN GROUP (ORDER BY SECURITY_NAME)
                      AS SECURITY_NAME
              INTO vSecurityAmt, vSecurityType
              FROM loan.LOAN_SECURITY x, loan.SECURITY_TYPE y
             WHERE     x.ac_id = a.ac_id
                   AND status = 'Y'
                   AND x.SECURITY_TYPE = y.SECURITY_CODE;
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               vSecurityType := NULL;
               vSecurityAmt := 0;
            WHEN OTHERS
            THEN
               vSanctionDate := NULL;
               vSecurityType := 0;
         END;


         vLoan_INFO (pdx).value_of_security := vSecurityAmt;
         vLoan_INFO (pdx).details_of_security := vSecurityType;



         BEGIN
            SELECT    EMOB.PKG_GLOBAL_OBJECTS.get_disrtict_name (
                         DISTRICT_CODE)
                   || ' '
                   || ADD_LINE1
              INTO vRegAdd
              FROM emob.mb_address_mst
             WHERE ref_no = a.cust_no AND ADDRESS_TYPE = 'REG';
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               vRegAdd := NULL;
            WHEN OTHERS
            THEN
               vRegAdd := NULL;
         END;

         vLoan_INFO (pdx).business_add := vRegAdd;



         BEGIN
            SELECT    EMOB.PKG_GLOBAL_OBJECTS.get_disrtict_name (
                         DISTRICT_CODE)
                   || ' '
                   || ADD_LINE1
              INTO vFacAdd
              FROM emob.mb_address_mst
             WHERE ref_no = a.cust_no AND ADDRESS_TYPE = 'FAC';
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               vFacAdd := NULL;
            WHEN OTHERS
            THEN
               vFacAdd := NULL;
         END;

         IF vFacAdd IS NULL
         THEN
            vFacAdd := vRegAdd;
         END IF;

         vLoan_INFO (pdx).fac_add := vFacAdd;



         BEGIN
            SELECT LISTAGG (address, ',') WITHIN GROUP (ORDER BY address)
                      AS owner_details
              INTO vOwnerDetails
              FROM (SELECT    EMOB.PKG_GLOBAL_OBJECTS.GET_CUSTOMER_NAME (
                                 x.SHAREHOLDER_CUST_NO)
                           || ','
                           || (SELECT    EMOB.PKG_GLOBAL_OBJECTS.get_disrtict_name (
                                            DISTRICT_CODE)
                                      || ' '
                                      || ADD_LINE1
                                 FROM emob.mb_address_mst t
                                WHERE     t.ref_no = x.SHAREHOLDER_CUST_NO
                                      AND ADDRESS_TYPE = 'PRS')
                              AS address
                      FROM emob.MB_SHAREHOLDER_MST x
                     WHERE COMPANY_CUST_NO = a.cust_no);
         EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
               vOwnerDetails := NULL;
            WHEN OTHERS
            THEN
               vOwnerDetails := NULL;
         END;


         vLoan_INFO (pdx).owner_deatils := vOwnerDetails;

         IF ROUND (a.group_total / vFiEquity, 2) >= .15
         THEN
            vTotal_eqty := vTotal_eqty + ROUND (a.os / vFiEquity, 2);
            vLoan_INFO (pdx).include_flag := 'Y';
         END IF;


         IF vTotal_eqty >= 1.099
         THEN
            EXIT;
         END IF;
      END LOOP;


      BEGIN
         FOR i IN 1 .. pdx
         LOOP
            PIPE ROW (vLoan_INFO (i));
         --i:=i+1;
         END LOOP;

         RETURN;
      EXCEPTION
         WHEN NO_DATA_NEEDED
         THEN
            NULL;
      END;
   EXCEPTION
      WHEN vMyException
      THEN
         raise_application_error (-20101, vErrorMessage);
   END;
END;
/