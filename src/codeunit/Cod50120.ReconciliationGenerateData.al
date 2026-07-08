codeunit 50120 "Reconciliation Generate Data"
{
    TableNo = "Reconciliation Parm Buffer";
    trigger OnRun()
    var
        ReconciliationParmBuffer: Record "Reconciliation Parm Buffer";
    BEGIN

        IF ISNULLGUID(Rec.GUID) THEN
            EXIT;

        ReconciliationParmBuffer.SETRANGE(GUID, Rec.GUID);
        IF NOT ReconciliationParmBuffer.Findset() THEN
            EXIT;

        GeneralLedgerSetup.Get();

        REPEAT
            CASE ReconciliationParmBuffer."Extraction Type" OF
                ReconciliationParmBuffer."Extraction Type"::BlackLine_NF_BlackLine_Account_Items:
                    Extract_Open_Items(ReconciliationParmBuffer);
                ReconciliationParmBuffer."Extraction Type"::BlackLine_Bank:
                    Extract_BankAcc(ReconciliationParmBuffer);
                ReconciliationParmBuffer."Extraction Type"::BlackLine_Customer:
                    Extract_Customer(ReconciliationParmBuffer);
                ReconciliationParmBuffer."Extraction Type"::BlackLine_GL_Account_Balance:
                    Extract_GLAcc(ReconciliationParmBuffer);
                ReconciliationParmBuffer."Extraction Type"::BlackLine_Vendor:
                    Extract_Vendor(ReconciliationParmBuffer);
                ReconciliationParmBuffer."Extraction Type"::BlackLine_IC_ACC:
                    Extract_IC_ACC(ReconciliationParmBuffer);
                ReconciliationParmBuffer."Extraction Type"::BlackLine_IC_BAL:
                    Extract_IC_BAL(ReconciliationParmBuffer);
                ReconciliationParmBuffer."Extraction Type"::BlackLine_IC_FIN:
                    Extract_IC_FIN(ReconciliationParmBuffer);
                ReconciliationParmBuffer."Extraction Type"::BlackLine_IC_FV:
                    Extract_IC_FV(ReconciliationParmBuffer);
                ReconciliationParmBuffer."Extraction Type"::BlackLine_IC_INT:
                    Extract_IC_INT(ReconciliationParmBuffer);
                ReconciliationParmBuffer."Extraction Type"::BlackLine_IC_PnL:
                    Extract_IC_Pnl(ReconciliationParmBuffer);
            END;
        UNTIL ReconciliationParmBuffer.Next() = 0;
    end;

    var
        GeneralLedgerSetup: Record 98;
        ReconciliationBuffer: Record "Reconciliation Buffer" temporary;
        TempBlob: codeunit "Temp Blob";
        OutStr: OutStream;
        CR: Char;
        LF: Char;
        HJ_DateFIlter: Text[30];
        HJ_NoFilter: Text[250];
        WebServiceLog: Record 82027;

    procedure Extract_Match_Items(p_ReconParmBuffer: Record 82191);
    var
        GLEntry: Record 17;
        BTReconGLOutboundEntry: Record 82190;
        GLAccount: Record 15;
        Send: Boolean;
        BTNAVOutboundData: Record 82002;
        Last_Full_Guid: GUID;
        Last_Entry_No: Integer;
        Last_Incr_Guid: GUID;
        i: Integer;
    BEGIN
        CLEAR(GLAccount);
        GLAccount.SETRANGE("Blackline Match", TRUE);
        IF NOT GLAccount.Findset() THEN
            EXIT;

        i := 0;
        CLEAR(BTReconGLOutboundEntry);
        IF BTReconGLOutboundEntry.Findlast() THEN
            i := BTReconGLOutboundEntry."Entry No.";

        REPEAT
            //Find last entry exported per. account.
            Last_Entry_No := 0;
            CLEAR(BTReconGLOutboundEntry);
            BTReconGLOutboundEntry.SETCURRENTKEY("Export Date/Time");
            BTReconGLOutboundEntry.SETRANGE(CompanyID, CompanyName());
            BTReconGLOutboundEntry.SETRANGE("Execution Mode", p_ReconParmBuffer."Execution Mode");
            BTReconGLOutboundEntry.SETRANGE("Extraction Type", p_ReconParmBuffer."Extraction Type");
            BTReconGLOutboundEntry.SETRANGE("G/L Account No.", GLAccount."No.");

            IF BTReconGLOutboundEntry.Findlast() THEN
                Last_Full_Guid := BTReconGLOutboundEntry.Batch_Guid;
            BTReconGLOutboundEntry.SETCURRENTKEY(Batch_Guid, "G/L Entry No.");
            BTReconGLOutboundEntry.SETRANGE(Batch_Guid, Last_Full_Guid);
            IF BTReconGLOutboundEntry.Findlast() THEN
                Last_Entry_No := BTReconGLOutboundEntry."G/L Entry No.";

            CLEAR(GLEntry);
            GLEntry.SETCURRENTKEY("G/L Account No.", "Posting Date");
            GLEntry.SETRANGE("G/L Account No.", GLAccount."No.");
            GLEntry.SETRANGE("Entry No.", Last_Entry_No + 1, 999999999);

            //Write_Debug_Info('Incr.:'+FORMAT(Last_Incr_Guid));

            IF GLEntry.Findset() THEN BEGIN
                REPEAT
                    Send := TRUE;

                    GLEntry.CALCFIELDS("Remaining Amount (new)");

                    IF Send = TRUE THEN BEGIN
                        WITH BTReconGLOutboundEntry DO BEGIN
                            CLEAR(BTReconGLOutboundEntry);
                            INIT;
                            i += 1;
                            "Entry No." := i;
                            "Inserted By" := UserId();
                            Status := Status::Open;
                            CompanyID := CompanyName();
                            "Inserted Date/Time" := CurrentDateTime();

                            "G/L Account No." := GLEntry."G/L Account No.";
                            "Posting Date" := GLEntry."Posting Date";

                            IF isDirtyText(GLEntry.Description) THEN
                                Description := cleanRow(GLEntry.Description)
                            ELSE
                                Description := GLEntry.Description;

                            Amount := GLEntry.Amount;
                            "IC Partner Code" := GLEntry."IC Partner Code";
                            "Remaining Amount" := GLEntry."Remaining Amount (new)";
                            "G/L Entry No." := GLEntry."Entry No.";
                            "Creation Date" := GLEntry."Creation Date";
                            "Document No." := GLEntry."Document No.";

                            IF isDirtyText(GLEntry."External Document No.") THEN
                                "External Document No." := cleanRow(GLEntry."External Document No.")
                            ELSE
                                "External Document No." := GLEntry."External Document No.";

                            "Currency Code" := GeneralLedgerSetup."LCY Code";
                            "Global Dimension 1 Code" := GLEntry."Global Dimension 1 Code";

                            IF "Posting Date" > CALCDATE('<-CM-1D>', WorkDate()) THEN
                                "Open Date" := "Posting Date"
                            ELSE
                                "Open Date" := CALCDATE('<-CM-1D>', WorkDate());

                            "Extraction Type" := p_ReconParmBuffer."Extraction Type";
                            "Execution Mode" := p_ReconParmBuffer."Execution Mode";
                            Batch_Guid := p_ReconParmBuffer.GUID;
                            "Export Date/Time" := CURRENTDATETIME();

                            INSERT;
                        END;
                    END;
                UNTIL GLEntry.Next() = 0;
            END;
        UNTIL GLAccount.Next() = 0;
        //<NF> #3593734  Filudtrk til Blackline afstemning
    END;

    local procedure Extract_Open_Items(p_ReconParmBuffer: Record 82191);
    var
        GLEntry: Record 17;
        BTReconGLOutboundEntry: Record 82190;
        GLAccount: Record 15;
        Send: Boolean;
        BTNAVOutboundData: Record 82002;
        Last_Full_Guid: GUID;
        Last_Entry_No: Integer;
        Last_Incr_Guid: GUID;
        i: Integer;
    BEGIN
        CLEAR(GLAccount);
        GLAccount.SETRANGE("Blackline Not included", FALSE);
        GLAccount.SETRANGE("Income/Balance", GLAccount."Income/Balance"::"Balance Sheet");
        GLAccount.SETRANGE("Blackline Item Reconciliation", GLAccount."Blackline Item Reconciliation"::Item);
        GLAccount.SETRANGE("Account Type", GLAccount."Account Type"::Posting);

        //TEST
        //GLAccount.SETRANGE("No.",'934510');

        IF NOT GLAccount.Findset() THEN
            EXIT;

        IF p_ReconParmBuffer."Execution Mode" = p_ReconParmBuffer."Execution Mode"::Incremental THEN BEGIN
            CLEAR(BTReconGLOutboundEntry);
            BTReconGLOutboundEntry.SETCURRENTKEY("Export Date/Time", "Execution Mode", Batch_Guid);
            BTReconGLOutboundEntry.SETRANGE(CompanyID, CompanyName());
            BTReconGLOutboundEntry.SETRANGE("Execution Mode", BTReconGLOutboundEntry."Execution Mode"::Incremental);
            //<NF> #6475010  Blackline item issues balance afstemning
            BTReconGLOutboundEntry.SETRANGE("Extraction Type", BTReconGLOutboundEntry."Extraction Type"::BlackLine_NF_BlackLine_Account_Items);
            //</NF> #6475010  Blackline item issues balance afstemning
            IF BTReconGLOutboundEntry.Findlast() THEN
                Last_Incr_Guid := BTReconGLOutboundEntry.Batch_Guid;
            BTReconGLOutboundEntry.SETRANGE("Execution Mode", BTReconGLOutboundEntry."Execution Mode"::Full);
            IF BTReconGLOutboundEntry.Findlast() THEN
                Last_Full_Guid := BTReconGLOutboundEntry.Batch_Guid;
            BTReconGLOutboundEntry.SETCURRENTKEY(Batch_Guid, "G/L Entry No.");
            BTReconGLOutboundEntry.SETRANGE(Batch_Guid, Last_Full_Guid);
            IF BTReconGLOutboundEntry.Findlast() THEN
                Last_Entry_No := BTReconGLOutboundEntry."G/L Entry No.";
        END;

        i := 0;
        CLEAR(BTReconGLOutboundEntry);
        IF BTReconGLOutboundEntry.Findlast() THEN
            i := BTReconGLOutboundEntry."Entry No.";

        REPEAT
            CLEAR(GLEntry);
            GLEntry.SETCURRENTKEY("G/L Account No.", "Posting Date");
            GLEntry.SETRANGE("G/L Account No.", GLAccount."No.");
            GLEntry.SETFILTER("Posting Date", '..%1', CALCDATE('<-CM-1D>', WORKDATE()));
            GLEntry.SETFILTER("Date Filter (new)", '..%1', CALCDATE('<-CM-1D>', WORKDATE()));

            //Write_Debug_Info('Incr.:'+FORMAT(Last_Incr_Guid));

            IF GLEntry.Findset() THEN BEGIN
                REPEAT
                    Send := TRUE;

                    GLEntry.CALCFIELDS("Remaining Amount (new)");
                    IF p_ReconParmBuffer."Execution Mode" = p_ReconParmBuffer."Execution Mode"::Full THEN BEGIN
                        IF GLEntry."Remaining Amount (new)" = 0 THEN
                            Send := FALSE;
                    END;
                    IF p_ReconParmBuffer."Execution Mode" = p_ReconParmBuffer."Execution Mode"::Incremental THEN BEGIN
                        Send := FALSE;
                        //IF the entry amount now is <> 0 in remaining amount and it was not in the last full load (was 0 in amount) - it is sent..
                        CLEAR(BTReconGLOutboundEntry);
                        BTReconGLOutboundEntry.SETCURRENTKEY(Batch_Guid, CompanyID, "G/L Account No.", "Extraction Type", "Execution Mode", "G/L Entry No.");
                        BTReconGLOutboundEntry.SETRANGE(Batch_Guid, Last_Full_Guid);
                        BTReconGLOutboundEntry.SETRANGE(CompanyID, CompanyName());
                        BTReconGLOutboundEntry.SETRANGE("G/L Account No.", GLEntry."G/L Account No.");
                        BTReconGLOutboundEntry.SETRANGE("Extraction Type", BTReconGLOutboundEntry."Extraction Type"::BlackLine_NF_BlackLine_Account_Items);
                        BTReconGLOutboundEntry.SETRANGE("Execution Mode", BTReconGLOutboundEntry."Execution Mode"::Full);
                        BTReconGLOutboundEntry.SETRANGE("G/L Entry No.", GLEntry."Entry No.");
                        IF (NOT BTReconGLOutboundEntry.Findfirst()) AND (GLEntry."Remaining Amount (new)" <> 0) THEN
                            Send := TRUE;

                        //If amount in the entry is different from the amount in the last full load - it is sent..
                        IF Send = FALSE THEN BEGIN
                            IF BTReconGLOutboundEntry.Findfirst() THEN
                                IF GLEntry."Remaining Amount (new)" <> BTReconGLOutboundEntry."Remaining Amount" THEN
                                    Send := TRUE;
                        END;

                        //If the entry is new compared to last full load and remaining amount is <> 0 - it is sent..
                        IF Send = FALSE THEN BEGIN
                            IF (GLEntry."Entry No." > Last_Entry_No) AND (GLEntry."Remaining Amount (new)" <> 0) THEN
                                Send := TRUE;
                        END;

                        //IF entry exist in an incremental load and amount has changed, it is sent - if not it is NOT sent..
                        //<NF> #5729653  Item fil til Blackline
                        //BTReconGLOutboundEntry.SETRANGE(Batch_Guid, Last_Incr_Guid);

                        //BTReconGLOutboundEntry.SETCURRENTKEY(CompanyID, "G/L Account No.", "G/L Entry No.", "Entry No.");
                        //BTReconGLOutboundEntry.SETFILTER(Batch_Guid, '<>%1', p_ReconParmBuffer.GUID);
                        BTReconGLOutboundEntry.SETCURRENTKEY("Extraction Type", "Execution Mode", "G/L Entry No.");
                        BTReconGLOutboundEntry.SETRANGE(Batch_Guid);
                        BTReconGLOutboundEntry.SETRANGE("Execution Mode", BTReconGLOutboundEntry."Execution Mode"::Incremental);
                        IF BTReconGLOutboundEntry.Findlast() THEN BEGIN
                            IF GLEntry."Remaining Amount (new)" <> BTReconGLOutboundEntry."Remaining Amount" THEN
                                Send := TRUE
                            ELSE
                                Send := FALSE;
                        END;
               {
               IF BTReconGLOutboundEntry.Findfirst() THEN BEGIN
                            IF GLEntry."Remaining Amount (new)" <> BTReconGLOutboundEntry."Remaining Amount" THEN
                                Send := TRUE
                            ELSE
                                Send := FALSE;
                        END;
               }
               //</NF> #5729653  Item fil til Blackline
            END;

            IF Send = TRUE THEN BEGIN
                WITH BTReconGLOutboundEntry DO BEGIN
                    CLEAR(BTReconGLOutboundEntry);
                    INIT;
                    i += 1;
                    "Entry No." := i;
                    "Inserted By" := UserId();
                    Status := Status::Open;
                    CompanyID := CompanyName();
                    "Inserted Date/Time" := CurrentDateTime();

                    "G/L Account No." := GLEntry."G/L Account No.";
                    "Posting Date" := GLEntry."Posting Date";

                    IF isDirtyText(GLEntry.Description) THEN
                        Description := cleanRow(GLEntry.Description)
                    ELSE
                        Description := GLEntry.Description;

                    Amount := GLEntry.Amount;
                    "IC Partner Code" := GLEntry."IC Partner Code";
                    "Remaining Amount" := GLEntry."Remaining Amount (new)";
                    "G/L Entry No." := GLEntry."Entry No.";
                    "Creation Date" := GLEntry."Creation Date";
                    "Document No." := GLEntry."Document No.";

                    IF isDirtyText(GLEntry."External Document No.") THEN
                        "External Document No." := cleanRow(GLEntry."External Document No.")
                    ELSE
                        "External Document No." := GLEntry."External Document No.";

                    "Currency Code" := GeneralLedgerSetup."LCY Code";
                    "Global Dimension 1 Code" := GLEntry."Global Dimension 1 Code";

                    IF "Posting Date" > CALCDATE('<-CM-1D>', WorkDate()) THEN
                        "Open Date" := "Posting Date"
                    ELSE
                        "Open Date" := CALCDATE('<-CM-1D>', WorkDate());

                    "Extraction Type" := p_ReconParmBuffer."Extraction Type";
                    "Execution Mode" := p_ReconParmBuffer."Execution Mode";
                    Batch_Guid := p_ReconParmBuffer.GUID;
                    "Export Date/Time" := CURRENTDATETIME();

                    INSERT;
                END;
            END;
        UNTIL GLEntry.Next() = 0;
    END;
      UNTIL GLAccount.Next() = 0;
    END;

    local procedure Extract_BankAcc(p_ReconParmBuffer : Record 82191);
    var
      BankAccount : Record 270;
      BTReconMasterOutbEntry : Record 82158;
      BankAccountPostingGroup : Record 277;
      i : Integer;
    BEGIN
      CLEAR(BankAccount);
      BankAccount.SETRANGE(Blocked, FALSE);

      IF NOT BankAccount.Findset() THEN
        EXIT;

      BankAccount.SETFILTER("Date Filter", '..%1', CALCDATE('<-CM-1D>', WORKDATE()));

      i := 0;
      IF BTReconMasterOutbEntry.Findlast() THEN
        i := BTReconMasterOutbEntry."Entry No.";

      REPEAT
        BankAccount.CALCFIELDS("Net Change", "Net Change (LCY)");
        WITH BTReconMasterOutbEntry DO BEGIN
          i += 1;
          INIT;
          "Entry No." := i;
          "Inserted By" := UserId();
          Status := Status::Open;
          CompanyID := CompanyName();
          "Inserted Date/Time" := CurrentDateTime();

          "No." := BankAccount."No.";
          //<NF> #32246519  Customer ledger fil til Blackline fejler
          //Name   := BankAccount.Name;
          IF isDirtyText(BankAccount.Name) THEN
             Name := cleanRow(BankAccount.Name)
          ELSE
             Name   := BankAccount.Name;
          //</NF> #32246519  Customer ledger fil til Blackline fejler
          Balance := BankAccount."Net Change";
          "Balance (LCY)" := BankAccount."Net Change (LCY)";
          IF BankAccountPostingGroup.GET(BankAccount."Bank Acc. Posting Group") THEN
            "G/L Account" := BankAccountPostingGroup."G/L Bank Account No.";

          Type := Type::Bank;
          Currency := BankAccount."Currency Code";
          IF Currency = '' THEN
            Currency := GeneralLedgerSetup."LCY Code";
          "Last Date of the period" := CALCDATE('<-CM-1D>', WORKDATE());

          "Extraction Type" := p_ReconParmBuffer."Extraction Type";
          "Execution Mode" := p_ReconParmBuffer."Execution Mode";
          Batch_Guid        := p_ReconParmBuffer.GUID;
          "Export Date/Time" := CURRENTDATETIME();

          INSERT;
        END;
      UNTIL BankAccount.Next() = 0;
    END;

    local procedure Extract_Customer(p_ReconParmBuffer : Record 82191);
    var
      Customer : Record 18;
      BTReconMasterOutbEntry : Record 82158;
      CustomerPostingGroup : Record 92;
      Last_Full_Guid : GUID;
      Last_Incr_Guid : GUID;
      i : Integer;
      Send : Boolean;
    BEGIN
      CLEAR(Customer);

      IF NOT Customer.Findset() THEN
        EXIT;

      IF p_ReconParmBuffer."Execution Mode" = p_ReconParmBuffer."Execution Mode"::Incremental THEN BEGIN
        CLEAR(BTReconMasterOutbEntry);
        BTReconMasterOutbEntry.SETCURRENTKEY("Export Date/Time");
        BTReconMasterOutbEntry.SETRANGE(CompanyID, CompanyName());
        BTReconMasterOutbEntry.SETRANGE("Execution Mode", BTReconMasterOutbEntry."Execution Mode"::Incremental);
        BTReconMasterOutbEntry.SETRANGE(Type, BTReconMasterOutbEntry.Type::Customer);
        IF BTReconMasterOutbEntry.Findlast() THEN
          Last_Incr_Guid := BTReconMasterOutbEntry.Batch_Guid;
        BTReconMasterOutbEntry.SETRANGE("Execution Mode", BTReconMasterOutbEntry."Execution Mode"::Full);
        IF BTReconMasterOutbEntry.Findlast() THEN
          Last_Full_Guid := BTReconMasterOutbEntry.Batch_Guid;
      END;

      Customer.SETFILTER("Date Filter", '..%1', CALCDATE('<-CM-1D>', WORKDATE()));

      i := 0;
      CLEAR(BTReconMasterOutbEntry);
      IF BTReconMasterOutbEntry.Findlast() THEN
        i := BTReconMasterOutbEntry."Entry No.";

      //Write_Debug_Info('Incr.:'+FORMAT(Last_Incr_Guid));
      //Write_Debug_Info('Full.:'+FORMAT(Last_Full_Guid));

      REPEAT
        Send := TRUE;
        Customer.CALCFIELDS("Net Change", "Net Change (LCY)");

        IF p_ReconParmBuffer."Execution Mode" = p_ReconParmBuffer."Execution Mode"::Full THEN BEGIN
           IF Customer."Net Change (LCY)" = 0 THEN
              Send := FALSE;
        END;
        IF p_ReconParmBuffer."Execution Mode" = p_ReconParmBuffer."Execution Mode"::Incremental THEN BEGIN
           Send := FALSE;
          //IF the entry amount now is <> 0 in and it was not in the last full load (was 0 in amount) - it is sent..
          CLEAR(BTReconMasterOutbEntry);
          BTReconMasterOutbEntry.SETCURRENTKEY(Batch_Guid, CompanyID, "No.");
          BTReconMasterOutbEntry.SETRANGE(CompanyID, CompanyName());
          BTReconMasterOutbEntry.SETRANGE(Batch_Guid, Last_Full_Guid);
          BTReconMasterOutbEntry.SETRANGE("No.", Customer."No.");
          BTReconMasterOutbEntry.SETRANGE(Type, BTReconMasterOutbEntry.Type::Customer);
          IF (BTReconMasterOutbEntry.Isempty()) AND (Customer."Net Change (LCY)" <> 0) THEN
             Send := TRUE;

          //If amount in the entry is different from the amount in the last full load - it is sent..
          IF Send = FALSE THEN BEGIN
            IF BTReconMasterOutbEntry.Findfirst() THEN
              IF Customer."Net Change (LCY)" <> BTReconMasterOutbEntry."Balance (LCY)" THEN
                 Send := TRUE;
          END;

          //IF entry exist in the last incremental load and amount has changed, it is sent - if not it is NOT sent..
          BTReconMasterOutbEntry.SETRANGE(Batch_Guid, Last_Incr_Guid);
          IF BTReconMasterOutbEntry.Findfirst() THEN BEGIN
            IF Customer."Net Change (LCY)" <> BTReconMasterOutbEntry."Balance (LCY)" THEN
               Send := TRUE
            ELSE
               Send := FALSE;
          END;
        END;

        IF Send = TRUE THEN BEGIN
          WITH BTReconMasterOutbEntry DO BEGIN
            i += 1;
            INIT;
            "Entry No." := i;
            "Inserted By" := UserId();
            Status := Status::Open;
            CompanyID := CompanyName();
            "Inserted Date/Time" := CurrentDateTime();

            "No." := Customer."No.";
            //<NF> #32246519  Customer ledger fil til Blackline fejler
            //Name   := Customer.Name;
            IF isDirtyText(Customer.Name) THEN
               Name := cleanRow(Customer.Name)
            ELSE
               Name   := Customer.Name;
            //</NF> #32246519  Customer ledger fil til Blackline fejler
            Balance := Customer."Net Change";
            "Balance (LCY)" := Customer."Net Change (LCY)";
            IF CustomerPostingGroup.GET(Customer."Customer Posting Group") THEN
              "G/L Account" := CustomerPostingGroup."Receivables Account";

            Type := Type::Customer;
            Currency := GeneralLedgerSetup."LCY Code";
            "Last Date of the period" := CALCDATE('<-CM-1D>', WORKDATE());

            "Extraction Type" := p_ReconParmBuffer."Extraction Type";
            "Execution Mode" := p_ReconParmBuffer."Execution Mode";
            Batch_Guid        := p_ReconParmBuffer.GUID;
            "Export Date/Time" := CURRENTDATETIME();

            INSERT;
          END;
        END;
      UNTIL Customer.Next() = 0;
    END;

    local procedure Extract_Vendor(p_ReconParmBuffer : Record 82191);
    var
      Vendor : Record 23;
      BTReconMasterOutbEntry : Record 82158;
      VendorPostingGroup : Record 93;
      Last_Full_Guid : GUID;
      Last_Incr_Guid : GUID;
      i : Integer;
      Send : Boolean;
    BEGIN
      CLEAR(Vendor);

      IF NOT Vendor.Findset() THEN
        EXIT;

      IF p_ReconParmBuffer."Execution Mode" = p_ReconParmBuffer."Execution Mode"::Incremental THEN BEGIN
        CLEAR(BTReconMasterOutbEntry);
        BTReconMasterOutbEntry.SETCURRENTKEY("Export Date/Time");
        BTReconMasterOutbEntry.SETRANGE(CompanyID, CompanyName());
        BTReconMasterOutbEntry.SETRANGE("Execution Mode", BTReconMasterOutbEntry."Execution Mode"::Incremental);
        BTReconMasterOutbEntry.SETRANGE(Type, BTReconMasterOutbEntry.Type::Vendor);
        IF BTReconMasterOutbEntry.Findlast() THEN
          Last_Incr_Guid := BTReconMasterOutbEntry.Batch_Guid;
        BTReconMasterOutbEntry.SETRANGE("Execution Mode", BTReconMasterOutbEntry."Execution Mode"::Full);
        IF BTReconMasterOutbEntry.Findlast() THEN
          Last_Full_Guid := BTReconMasterOutbEntry.Batch_Guid;
      END;

      Vendor.SETFILTER("Date Filter", '..%1', CALCDATE('<-CM-1D>', WORKDATE()));

      i := 0;
      CLEAR(BTReconMasterOutbEntry);
      IF BTReconMasterOutbEntry.Findlast() THEN
         i := BTReconMasterOutbEntry."Entry No.";

      //Write_Debug_Info('Incr.:'+FORMAT(Last_Incr_Guid));
      //Write_Debug_Info('Full.:'+FORMAT(Last_Full_Guid));

      REPEAT
        Send := TRUE;
        Vendor.CALCFIELDS("Net Change", "Net Change (LCY)");

        IF p_ReconParmBuffer."Execution Mode" = p_ReconParmBuffer."Execution Mode"::Full THEN BEGIN
           IF Vendor."Net Change (LCY)" = 0 THEN
              Send := FALSE;
        END;
        IF p_ReconParmBuffer."Execution Mode" = p_ReconParmBuffer."Execution Mode"::Incremental THEN BEGIN
           Send := FALSE;
          //IF the entry amount now is <> 0 in and it was not in the last full load (was 0 in amount) - it is sent..
          CLEAR(BTReconMasterOutbEntry);
          BTReconMasterOutbEntry.SETCURRENTKEY(Batch_Guid, CompanyID, "No.");
          BTReconMasterOutbEntry.SETRANGE(CompanyID, CompanyName());
          BTReconMasterOutbEntry.SETRANGE(Batch_Guid, Last_Full_Guid);
          BTReconMasterOutbEntry.SETRANGE("No.", Vendor."No.");
          BTReconMasterOutbEntry.SETRANGE(Type, BTReconMasterOutbEntry.Type::Vendor);
          IF (BTReconMasterOutbEntry.Isempty()) AND (Vendor."Net Change (LCY)" <> 0) THEN
             Send := TRUE;

          //If amount in the entry is different from the amount in the last full load - it is sent..
          IF Send = FALSE THEN BEGIN
            IF BTReconMasterOutbEntry.Findfirst() THEN
              IF (Vendor."Net Change (LCY)"*-1) <> BTReconMasterOutbEntry."Balance (LCY)" THEN
                 Send := TRUE;
          END;

          //IF entry exist in the last incremental load and amount has changed, it is sent - if not it is NOT sent..
          BTReconMasterOutbEntry.SETRANGE(Batch_Guid, Last_Incr_Guid);
          IF BTReconMasterOutbEntry.Findfirst() THEN BEGIN
            IF (Vendor."Net Change (LCY)"*-1) <> BTReconMasterOutbEntry."Balance (LCY)" THEN
               Send := TRUE
            ELSE
               Send := FALSE;
          END;
        END;

        IF Send = TRUE THEN BEGIN
          WITH BTReconMasterOutbEntry DO BEGIN
            i += 1;
            INIT;
            "Entry No." := i;
            "Inserted By" := UserId();
            Status := Status::Open;
            CompanyID := CompanyName();
            "Inserted Date/Time" := CurrentDateTime();

            "No." := Vendor."No.";
            //<NF> #32246519  Customer ledger fil til Blackline fejler
            //Name   := Vendor.Name;
            IF isDirtyText(Vendor.Name) THEN
               Name := cleanRow(Vendor.Name)
            ELSE
               Name   := Vendor.Name;
            //</NF> #32246519  Customer ledger fil til Blackline fejler
            Balance := Vendor."Net Change"*-1;
            "Balance (LCY)" := Vendor."Net Change (LCY)"*-1;
            IF VendorPostingGroup.GET(Vendor."Vendor Posting Group") THEN
              "G/L Account" := VendorPostingGroup."Payables Account";

            Type := Type::Vendor;
            Currency := GeneralLedgerSetup."LCY Code";
            "Last Date of the period" := CALCDATE('<-CM-1D>', WORKDATE());

            "Extraction Type" := p_ReconParmBuffer."Extraction Type";
            "Execution Mode" := p_ReconParmBuffer."Execution Mode";
            Batch_Guid        := p_ReconParmBuffer.GUID;
            "Export Date/Time" := CURRENTDATETIME();

            INSERT;
          END;
        END;
      UNTIL Vendor.Next() = 0;
    END;

    local procedure Extract_GLAcc(p_ReconParmBuffer : Record 82191);
    var
      GLAccount : Record 15;
      BTReconMasterOutbEntry : Record 82158;
      GeneralLedgerSetup : Record 98;
      GLEntry : Record 17;
      i : Integer;
    BEGIN
      CLEAR(GLAccount);
      GLAccount.SETRANGE("Account Type", GLAccount."Account Type"::Posting);
      GLAccount.SETRANGE("Blackline Not included", FALSE);
      GLAccount.SETRANGE("Income/Balance", GLAccount."Income/Balance"::"Balance Sheet");
      GLAccount.SETFILTER("Date Filter", '..%1', CALCDATE('<-CM-1D>', WORKDATE()));

      GeneralLedgerSetup.GET();
      IF NOT GLAccount.Findset() THEN
        EXIT;

      i := 0;
      IF BTReconMasterOutbEntry.Findlast() THEN
        i := BTReconMasterOutbEntry."Entry No.";

      REPEAT
        CLEAR(GLEntry);
        GLEntry.SETCURRENTKEY("G/L Account No.", "Posting Date");
        GLEntry.SETRANGE("G/L Account No.", GLAccount."No.");
        GLEntry.SETFILTER("Posting Date", '%1..%2', CALCDATE('-CM-1M', WORKDATE()),CALCDATE('<-CM-1D>', WORKDATE()));


        GLAccount.CALCFIELDS("Balance at Date");
        WITH BTReconMasterOutbEntry DO BEGIN
          i += 1;
          INIT;
          "Entry No." := i;
          "Inserted By" := UserId();
          Status := Status::Open;
          CompanyID := CompanyName();
          "Inserted Date/Time" := CurrentDateTime();

          "No." := GLAccount."No.";
          //<NF> #32246519  Customer ledger fil til Blackline fejler
          //Name   := GLAccount.Name;
          IF isDirtyText(GLAccount.Name) THEN
              Name := cleanRow(GLAccount.Name)
          ELSE
              Name   := GLAccount.Name;
          //</NF> #32246519  Customer ledger fil til Blackline fejler
          Balance := GLAccount."Balance at Date";
          Currency := GeneralLedgerSetup."LCY Code";
          IF GLAccount."Blackline Not included" = TRUE THEN
             "Active Account" := 'FALSE'
          ELSE
             "Active Account" := 'TRUE';
          IF GLEntry.Isempty() THEN
             "Any Activity in period" := 'FALSE'
          ELSE
             "Any Activity in period" := 'TRUE';
          "Last Date of the period" := CALCDATE('<-CM-1D>', WORKDATE());

          "Extraction Type" := p_ReconParmBuffer."Extraction Type";
          "Execution Mode" := p_ReconParmBuffer."Execution Mode";
          Batch_Guid        := p_ReconParmBuffer.GUID;
          "Export Date/Time" := CURRENTDATETIME();

          INSERT;
        END;
      UNTIL GLAccount.Next() = 0;
    END;

    local procedure Extract_IC(p_ReconParmBuffer : Record 82191;var p_GLAccount : Record 15);
    var
      BTReconGLOutboundEntry : Record 82190;
      Send : Boolean;
      BTNAVOutboundData : Record 82002;
      Last_Full_Guid : GUID;
      Last_Entry_No : Integer;
      Last_Incr_Guid : GUID;
      i : Integer;
      GL_Account_Int : Integer;
      GLEntry : Record 17;
      GeneralLedgerSetup : Record 98;
    BEGIN
      //<NF> #6231548  Blackline IC Partner filer fra NAV

      //TEST
      //GLAccount.SETRANGE("No.",'934510');

      IF NOT p_GLAccount.Findset() THEN
        EXIT;

      GeneralLedgerSetup.GET();

      i := 0;
      CLEAR(BTReconGLOutboundEntry);
      IF BTReconGLOutboundEntry.Findlast() THEN
        i := BTReconGLOutboundEntry."Entry No.";

      REPEAT
        //Write_Debug_Info(p_GLAccount.GETFILTERS);
        CLEAR(GLEntry);
        GLEntry.SETCURRENTKEY("G/L Account No.", "Posting Date");
        GLEntry.SETRANGE("G/L Account No.", p_GLAccount."No.");
        GLEntry.SETFILTER("IC Partner Code", '<>%1&<>%2', '', 'INTERN');
        GLEntry.SETFILTER("Document No.",'<>@*EXCH*');

        // Request #70163181 VS: IC filer december
        //IF DATE2DMY(WorkDate(),1) < 20 THEN
        IF DATE2DMY(WorkDate(),1) < 19 THEN
           GLEntry.SETRANGE("Posting Date", CALCDATE('-CM',CALCDATE('-CM-1D', WorkDate())),CALCDATE('CM',CALCDATE('-CM-1D', WorkDate())))
        ELSE
           GLEntry.SETRANGE("Posting Date", CALCDATE('-CM',WorkDate()),CALCDATE('CM',WorkDate()));

        IF GLEntry.Findset() THEN BEGIN
          REPEAT
            Send := TRUE;
            //Write_Debug_Info(GLEntry.GETFILTERS);
            GLEntry.CALCFIELDS("Remaining Amount (new)");

            IF Send = TRUE THEN BEGIN
              WITH BTReconGLOutboundEntry DO BEGIN
                CLEAR(BTReconGLOutboundEntry);
                INIT;
                i += 1;
                "Entry No." := i;
                "Inserted By" := UserId();
                Status := Status::Open;
                CompanyID := CompanyName();
                "Inserted Date/Time" := CurrentDateTime();

                "G/L Account No."       := GLEntry."G/L Account No.";
                "Posting Date"          := GLEntry."Posting Date";

                IF isDirtyText(GLEntry.Description) THEN
                   Description          := cleanRow(GLEntry.Description)
                ELSE
                   Description          := GLEntry.Description;

                "Currency Code"              := GeneralLedgerSetup."LCY Code";
                Amount                       := GLEntry.Amount;

                "Foreign Currency Code"      := GLEntry."Currency Code (System)";
                "Currency Amount"            := GLEntry."Currency Amount (System)";

                IF ("Foreign Currency Code" = '') OR ("Foreign Currency Code" = "Currency Code") THEN BEGIN
                   "Foreign Currency Code" := "Currency Code";
                  "Currency Amount"        := Amount;
                END;
                "Remaining Amount"      := Amount;
                {
                EVALUATE(GL_Account_Int, "G/L Account No.");
                IF ((GL_Account_Int >= 100000) AND (GL_Account_Int <= 800000)) OR
                   ((GL_Account_Int >= 900000) AND (GL_Account_Int <= 959999)) THEN BEGIN
                    Amount := Amount*-1;
                    "Currency Amount" := "Currency Amount"*-1;
                    "Remaining Amount" := "Remaining Amount"*-1;
                END;
                }

                "IC Partner Code"       := GLEntry."IC Partner Code";
                IF "IC Partner Code" = 'TRE1' THEN
                   "IC Partner Code" := 'TRE';

                "G/L Entry No."         := GLEntry."Entry No.";
                "Creation Date"         := GLEntry."Creation Date";
                "Document No."          := GLEntry."Document No.";

                "Document Date"         := GLEntry."Document Date";
                "Source No."            := GLEntry."Source No.";
                IF "Source No." = 'TRE1' THEN
                   "Source No." := 'TRE';

                "Source Type"           := FORMAT(GLEntry."Source Type");
                IF GLEntry."Source Type" = GLEntry."Source Type"::" " THEN
                   "Source Type"        := '';

                "Document Type"         := FORMAT(GLEntry."Document Type");
                IF GLEntry."Document Type" = GLEntry."Document Type"::" " THEN
                   "Document Type"      := '';

                IF isDirtyText(GLEntry."External Document No.") THEN
                   "External Document No." := cleanRow(GLEntry."External Document No.")
                ELSE
                   "External Document No." := GLEntry."External Document No.";


                "Global Dimension 1 Code" := GLEntry."Global Dimension 1 Code";

                IF "Posting Date" > CALCDATE('<-CM-1D>',WorkDate()) THEN
                   "Open Date" := "Posting Date"
                ELSE
                   "Open Date" := CALCDATE('<-CM-1D>',WorkDate());

                Closed := 'FALSE';
                IF GLEntry."Open (new)" = FALSE THEN
                   Closed := 'TRUE';

                "Extraction Type" := p_ReconParmBuffer."Extraction Type";
                "Execution Mode"  := "Execution Mode"::Full;
                Batch_Guid        := p_ReconParmBuffer.GUID;
                "Export Date/Time" := CURRENTDATETIME();

                INSERT;
              END;
            END;
          UNTIL GLEntry.Next() = 0;
        END;
      UNTIL p_GLAccount.Next() = 0;
      //</NF> #6231548  Blackline IC Partner filer fra NAV
    END;

    local procedure Extract_IC_ACC(p_ReconParmBuffer : Record 82191);
    var
      GLAccount : Record 15;
    BEGIN
      //<NF> #6231548  Blackline IC Partner filer fra NAV
      CLEAR(GLAccount);
      GLAccount.SETFILTER("No.",'843030|935140');
      Extract_IC(p_ReconParmBuffer,GLAccount);
      //</NF> #6231548  Blackline IC Partner filer fra NAV
    END;

    local procedure Extract_IC_BAL(p_ReconParmBuffer : Record 82191);
    var
      GLAccount : Record 15;
      BTReconMasterOutbEntry : Record 82158;
    BEGIN
      //<NF> #6231548  Blackline IC Partner filer fra NAV
      CLEAR(GLAccount);
      GLAccount.SETFILTER("No.",'843010|846535|933230|935110');
      Extract_IC(p_ReconParmBuffer,GLAccount);
      //</NF> #6231548  Blackline IC Partner filer fra NAV
    END;

    local procedure Extract_IC_FIN(p_ReconParmBuffer : Record 82191);
    var
      GLAccount : Record 15;
      BTReconMasterOutbEntry : Record 82158;
    BEGIN
      //<NF> #6231548  Blackline IC Partner filer fra NAV
      CLEAR(GLAccount);
      //<NF> #65428837
      //GLAccount.SETFILTER("No.",'821010|843020|924010|924020|935210|935220');
      GLAccount.SETFILTER("No.",'821010|843020|848015|924010|924020|935210|935220|947015');
      //</NF> #65428837
      Extract_IC(p_ReconParmBuffer,GLAccount);
      //</NF> #6231548  Blackline IC Partner filer fra NAV
    END;

    local procedure Extract_IC_FV(p_ReconParmBuffer : Record 82191);
    var
      GLAccount : Record 15;
      BTReconMasterOutbEntry : Record 82158;
    BEGIN
      //<NF> #6231548  Blackline IC Partner filer fra NAV
      CLEAR(GLAccount);
      GLAccount.SETFILTER("No.",'735300..735399|751000..751199|751211..751999');
      Extract_IC(p_ReconParmBuffer,GLAccount);
      //</NF> #6231548  Blackline IC Partner filer fra NAV
    END;

    local procedure Extract_IC_INT(p_ReconParmBuffer : Record 82191);
    var
      GLAccount : Record 15;
      BTReconMasterOutbEntry : Record 82158;
    BEGIN
      //<NF> #6231548  Blackline IC Partner filer fra NAV
      CLEAR(GLAccount);
      GLAccount.SETFILTER("No.",'723000..723999|735200..735299|743000..743999|751210');
      Extract_IC(p_ReconParmBuffer,GLAccount);
      //</NF> #6231548  Blackline IC Partner filer fra NAV
    END;

    local procedure Extract_IC_Pnl(p_ReconParmBuffer : Record 82191);
    var
      GLAccount : Record 15;
      BTReconMasterOutbEntry : Record 82158;
    BEGIN
      //<NF> #6231548  Blackline IC Partner filer fra NAV
      CLEAR(GLAccount);
      GLAccount.SETFILTER("No.",'1..255999|265000..265999|281000..281999|285000..285999|295000..295999|'+
                                '360000..369998|375000..375999|385000..385999|395000..395999|'+
                                '405000..405999|410000..410999|415000..499999|'+
                                '515000..516999|545000..545999|550000..550999|555000..585999|'+
                                '619000..632999|636000..636999|642000..642999|646000..646999|'+
      //<NF> #7658430  FW: Mapping 205210 og 205215
                                //'702000..702999|775010');
                                '702000..702999|775010&<>205210&<>205215');
      //</NF> #7658430  FW: Mapping 205210 og 205215

      Extract_IC(p_ReconParmBuffer,GLAccount);
      //</NF> #6231548  Blackline IC Partner filer fra NAV
    END;

    local procedure isDirtyText(textValue : Text): Boolean;
    var
      CR : Text[1];
      LF : Text[1];
      TAB : Text[1];
    BEGIN
      CR[1] := 13;
      LF[1] := 10;
      //<NF> #4181511  Slet blank felt i description - fejler i BL
      TAB[1] := 9;
      //</NF> #4181511  Slet blank felt i description - fejler i BL

      //<NF>
      //EXIT(NOT ((STRPOS(textValue,CR) = 0) AND (STRPOS(textValue,LF) = 0)));
      EXIT(NOT ((STRPOS(textValue,CR) = 0) AND (STRPOS(textValue,LF) = 0) AND (STRPOS(textValue,TAB) = 0)));
      //</NF>
    END;

    local procedure cleanRow(sourceText : Text): Text;
    var
      destinationText : Text;
      CR : Integer;
      LF : Integer;
      TAB : Integer;
      dp : Integer;
      sp : Integer;
      textInteger : Integer;
      rowChanged : Boolean;
    BEGIN
      CR := 13;
      LF := 10;
      //<NF> #4181511  Slet blank felt i description - fejler i BL
      TAB := 9;
      //</NF> #4181511  Slet blank felt i description - fejler i BL

      dp := 0;
      destinationText := '';
      FOR sp := 1 TO STRLEN(sourceText) DO BEGIN
        textInteger := sourceText[sp];
        CASE textInteger OF
          CR : BEGIN
            rowChanged := TRUE;
          END;
          LF : BEGIN
            rowChanged := TRUE;
          END;
          //<NF> #4181511  Slet blank felt i description - fejler i BL
          TAB : BEGIN
            rowChanged := TRUE;
          END;
          //</NF> #4181511  Slet blank felt i description - fejler i BL
        ELSE
          dp += 1;
          destinationText[dp] := sourceText[sp];
        END;
      END;
      EXIT(destinationText);
    END;

    procedure TestDirtyText();
    var
      t : Text;
      CR : Char;
      LF : Char;
      TAB : Text[1];
    BEGIN
      LF  := 10;
      CR  := 13;
      //<NF> #4181511  Slet blank felt i description - fejler i BL
      TAB[1] := 9;
      //</NF> #4181511  Slet blank felt i description - fejler i BL

      //t := 'Carsten'+FORMAT(LF)+' Steenberg'+FORMAT(CR)+'ioGates ApS - Re-invoice Christian Vollmers, FTD';
      t := 'ioGates ApS - Re-invoice Christian Vollmers, FTD';
      MESSAGE(t);
      IF isDirtyText(t) THEN
         MESSAGE(cleanRow(t));
      EXIT;
    END;

    local procedure Write_Debug_Info(p : Text[100]);
    var
      EntryBuffer : Record 82015;
      i : Integer;
    BEGIN
      i:= 1;
      IF EntryBuffer.Findlast() THEN
         i := EntryBuffer."Entry No.";
      EntryBuffer.Init();
      EntryBuffer."Entry No." := i + 1;
      EntryBuffer.Description := p;
      EntryBuffer.Insert();
    END;

    procedure TempGLEntryDataGeneratedOK(var p_Filter_Rec : Record 82210): Boolean;
    var
      TextManagement : Codeunit 41;
      i : Integer;
      l_DateFilter : Text[30];
      HJ_DT : DateTime;
      HJ_GUID : GUID;
      GeneralLedgerSetup : Record 98;
      GLAccount : Record 15;
      GLEntry : Record 17;
      i1 : Integer;
    BEGIN
      HJ_DT := CURRENTDATETIME();
      HJ_GUID := CREATEGUID();

      WebServiceLog.Insert_Log('WS Reconciliation GLEntry', HJ_GUID, HJ_DT,1);

      //Init_Execution();
      GeneralLedgerSetup.GET();

      CLEAR(GLAccount);
      //GLAccount.SETRANGE("Blackline Not included", FALSE);
      GLAccount.SETRANGE("Income/Balance", GLAccount."Income/Balance"::"Balance Sheet");
      GLAccount.SETRANGE("Blackline Item Reconciliation", GLAccount."Blackline Item Reconciliation"::Item);
      GLAccount.SETRANGE("Account Type", GLAccount."Account Type"::Posting);

      l_DateFilter := DELCHR(p_Filter_Rec.GETFILTER(DateFilter), '=', '''');
      HJ_NoFilter := DELCHR(p_Filter_Rec.GETFILTER(NoFilter), '=', '''');
      HJ_DateFIlter := l_DateFilter;

      IF l_DateFilter = '' THEN
         l_DateFilter := STRSUBSTNO('..%1', CALCDATE('<-CM-1D>', WORKDATE()));

      i1 := TextManagement.MakeDateFilter(l_DateFilter);

      IF HJ_NoFilter <> '' THEN
         GLAccount.SETFILTER("No.", HJ_NoFilter);

      IF NOT GLAccount.Findset() THEN BEGIN
        Fill_Out_TempBlob(GLAccount.GETFILTERS);
        WebServiceLog.Update_log_With_Reply_DT(HJ_GUID, TempBlob);
        EXIT(FALSE);
      END;

      i := 0;

      REPEAT
        CLEAR(GLEntry);
        GLEntry.SETCURRENTKEY("G/L Account No.", "Posting Date");
        GLEntry.SETRANGE("G/L Account No.", GLAccount."No.");
        GLEntry.SETFILTER("Posting Date", l_DateFilter);

        IF l_DateFilter <> '' THEN
           GLEntry.SETFILTER("Posting Date", l_DateFilter);
        IF GLEntry.Findset() THEN BEGIN
          REPEAT
            GLEntry.SETFILTER("Date Filter (new)", l_DateFilter);
            GLEntry.CALCFIELDS("Remaining Amount (new)");
            IF GLEntry."Remaining Amount (new)" <> 0 THEN BEGIN
              ReconciliationBuffer.Init();
              i += 1;
              ReconciliationBuffer."Entry No." := i;
              ReconciliationBuffer.CompanyID := CompanyName();
              ReconciliationBuffer.GL_Account_No := GLAccount."No.";
              ReconciliationBuffer.Description      := GLEntry.Description;
              ReconciliationBuffer."Posting Date" := FORMAT(GLEntry."Posting Date",0,'<day,2>-<Month,2>-<Year4>');
              ReconciliationBuffer."Amount LCY" := GLEntry.Amount;
              ReconciliationBuffer."IC Partner Code" := GLEntry."IC Partner Code";
              ReconciliationBuffer.Department := GLEntry."Global Dimension 1 Code";
              ReconciliationBuffer.GL_Entry_No := GLEntry."Entry No.";
              ReconciliationBuffer."Document No." := GLEntry."Document No.";
              ReconciliationBuffer."Creation Date" := FORMAT(GLEntry."Creation Date",0,'<day,2>-<Month,2>-<Year4>');
              ReconciliationBuffer."External Document No." := GLEntry."External Document No.";
              ReconciliationBuffer."Currency Code" := GeneralLedgerSetup."LCY Code";
              ReconciliationBuffer."Remaining Amount" := GLEntry."Remaining Amount (new)";
              ReconciliationBuffer.DateFilter := l_DateFilter;
              ReconciliationBuffer.NoFilter := HJ_NoFilter;
              ReconciliationBuffer.Insert();
            END;
          UNTIL GLEntry.Next() = 0;
        END;
      UNTIL GLAccount.Next() = 0;

      Fill_Out_TempBlob(GLAccount.GETFILTERS);
      WebServiceLog.Update_log_With_Reply_DT(HJ_GUID, TempBlob);

      EXIT(TRUE);

    END;

    procedure TempCustomerDataGeneratedOK(var p_Filter_Rec : Record 82210): Boolean;
    var
      TextManagement : Codeunit 41;
      i : Integer;
      l_DateFilter : Text[30];
      HJ_DT : DateTime;
      HJ_GUID : GUID;
      GeneralLedgerSetup : Record 98;
      Customer : Record 18;
      i1 : Integer;
      CustomerPostingGroup : Record 92;
    BEGIN
      HJ_DT := CURRENTDATETIME();
      HJ_GUID := CREATEGUID();
      WebServiceLog.Insert_Log('WS Reconciliation Customer', HJ_GUID, HJ_DT,1);
      //Init_Execution();
      GeneralLedgerSetup.GET();

      CLEAR(Customer);

      l_DateFilter := DELCHR(p_Filter_Rec.GETFILTER(DateFilter), '=', '''');
      HJ_NoFilter := DELCHR(p_Filter_Rec.GETFILTER(NoFilter), '=', '''');

      i1 := TextManagement.MakeDateFilter(l_DateFilter);

      IF l_DateFilter = '' THEN
         l_DateFilter := STRSUBSTNO('..%1', CALCDATE('<-CM-1D>', WORKDATE()));

      HJ_DateFIlter := l_DateFilter;

      IF HJ_NoFilter <> '' THEN
         Customer.SETFILTER("No.", HJ_NoFilter);

      IF NOT Customer.Findset() THEN BEGIN
        Fill_Out_TempBlob(Customer.GETFILTERS);
        WebServiceLog.Update_log_With_Reply_DT(HJ_GUID, TempBlob);
        EXIT(FALSE);
      END;

      i := 0;

      REPEAT
        Customer.SETFILTER("Date Filter", l_DateFilter);
        Customer.CALCFIELDS("Net Change (LCY)");
        IF Customer."Net Change (LCY)" <> 0 THEN BEGIN
          ReconciliationBuffer.Init();
          i += 1;
          ReconciliationBuffer."Entry No." := i;
          ReconciliationBuffer.CompanyID := CompanyName();
          IF CustomerPostingGroup.GET(Customer."Customer Posting Group") THEN
             ReconciliationBuffer.GL_Account_No := CustomerPostingGroup."Receivables Account";
          ReconciliationBuffer."Source No." := Customer."No.";
          ReconciliationBuffer.Description      := Customer.Name;
          ReconciliationBuffer."Amount LCY" := Customer."Net Change (LCY)";
          ReconciliationBuffer."Currency Code" := GeneralLedgerSetup."LCY Code";
          ReconciliationBuffer.Type := 'Balance_Subledger_Customer';
          ReconciliationBuffer.No := Customer."No.";
          ReconciliationBuffer.DateFilter := l_DateFilter;
          ReconciliationBuffer.NoFilter := HJ_NoFilter;
          ReconciliationBuffer.Insert();
        END;
      UNTIL Customer.Next() = 0;

      Fill_Out_TempBlob(Customer.GETFILTERS);
      WebServiceLog.Update_log_With_Reply_DT(HJ_GUID, TempBlob);

      EXIT(TRUE);

    END;

    procedure TempVendorDataGeneratedOK(var p_Filter_Rec : Record 82210): Boolean;
    var
      TextManagement : Codeunit 41;
      i : Integer;
      l_DateFilter : Text[30];
      HJ_DT : DateTime;
      HJ_GUID : GUID;
      GeneralLedgerSetup : Record 98;
      Vendor : Record 23;
      i1 : Integer;
      VendorPostingGroup : Record 93;
    BEGIN
      HJ_DT := CURRENTDATETIME();
      HJ_GUID := CREATEGUID();
      WebServiceLog.Insert_Log('WS Reconciliation Vendor', HJ_GUID, HJ_DT,1);
      //Init_Execution();
      GeneralLedgerSetup.GET();

      CLEAR(Vendor);

      l_DateFilter := DELCHR(p_Filter_Rec.GETFILTER(DateFilter), '=', '''');
      HJ_NoFilter := DELCHR(p_Filter_Rec.GETFILTER(NoFilter), '=', '''');

      i1 := TextManagement.MakeDateFilter(l_DateFilter);

      IF l_DateFilter = '' THEN
         l_DateFilter := STRSUBSTNO('..%1', CALCDATE('<-CM-1D>', WORKDATE()));

      HJ_DateFIlter := l_DateFilter;

      IF HJ_NoFilter <> '' THEN
         Vendor.SETFILTER("No.", HJ_NoFilter);

      IF NOT Vendor.Findset() THEN BEGIN
        Fill_Out_TempBlob(Vendor.GETFILTERS);
        WebServiceLog.Update_log_With_Reply_DT(HJ_GUID, TempBlob);
        EXIT(FALSE);
      END;

      i := 0;

      REPEAT
        Vendor.SETFILTER("Date Filter", l_DateFilter);
        Vendor.CALCFIELDS("Net Change (LCY)");
        IF Vendor."Net Change (LCY)" <> 0 THEN BEGIN
          ReconciliationBuffer.Init();
          i += 1;
          ReconciliationBuffer."Entry No." := i;
          ReconciliationBuffer.CompanyID := CompanyName();
          IF VendorPostingGroup.GET(Vendor."Vendor Posting Group") THEN
             ReconciliationBuffer.GL_Account_No := VendorPostingGroup."Payables Account";
          ReconciliationBuffer."Source No." := Vendor."No.";
          ReconciliationBuffer.Description      := Vendor.Name;
          ReconciliationBuffer."Amount LCY" := Vendor."Net Change (LCY)"*-1;
          ReconciliationBuffer."Currency Code" := GeneralLedgerSetup."LCY Code";
          ReconciliationBuffer.Type := 'Balance_Subledger_Vendor';
          ReconciliationBuffer.No := Vendor."No.";
          ReconciliationBuffer.DateFilter := l_DateFilter;
          ReconciliationBuffer.NoFilter := HJ_NoFilter;
          ReconciliationBuffer.Insert();
        END;
      UNTIL Vendor.Next() = 0;

      Fill_Out_TempBlob(Vendor.GETFILTERS);
      WebServiceLog.Update_log_With_Reply_DT(HJ_GUID, TempBlob);

      EXIT(TRUE);

    END;

    procedure TempBankDataGeneratedOK(var p_Filter_Rec : Record 82210): Boolean;
    var
      TextManagement : Codeunit 41;
      i : Integer;
      l_DateFilter : Text[30];
      HJ_DT : DateTime;
      HJ_GUID : GUID;
      GeneralLedgerSetup : Record 98;
      BankAcc : Record 270;
      i1 : Integer;
      BankPostingGroup : Record 277;
    BEGIN
      HJ_DT := CURRENTDATETIME();
      HJ_GUID := CREATEGUID();
      WebServiceLog.Insert_Log('WS Reconciliation BankAcc', HJ_GUID, HJ_DT,1);
      //Init_Execution();
      GeneralLedgerSetup.GET();

      CLEAR(BankAcc);

      l_DateFilter := DELCHR(p_Filter_Rec.GETFILTER(DateFilter), '=', '''');
      HJ_NoFilter := DELCHR(p_Filter_Rec.GETFILTER(NoFilter), '=', '''');

      i1 := TextManagement.MakeDateFilter(l_DateFilter);

      IF l_DateFilter = '' THEN
         l_DateFilter := STRSUBSTNO('..%1', CALCDATE('<-CM-1D>', WORKDATE()));

      HJ_DateFIlter := l_DateFilter;

      IF HJ_NoFilter <> '' THEN
         BankAcc.SETFILTER("No.", HJ_NoFilter);

      IF NOT BankAcc.Findset() THEN BEGIN
        Fill_Out_TempBlob(BankAcc.GETFILTERS);
        WebServiceLog.Update_log_With_Reply_DT(HJ_GUID, TempBlob);
        EXIT(FALSE);
      END;

      i := 0;

      REPEAT
        BankAcc.SETFILTER("Date Filter", l_DateFilter);
        BankAcc.CALCFIELDS("Net Change", "Net Change (LCY)");

        ReconciliationBuffer.Init();
        i += 1;
        ReconciliationBuffer."Entry No." := i;
        ReconciliationBuffer.CompanyID := CompanyName();
        IF BankPostingGroup.GET(BankAcc."Bank Acc. Posting Group") THEN
            ReconciliationBuffer.GL_Account_No := BankPostingGroup."G/L Bank Account No.";

        ReconciliationBuffer."Source No." := BankAcc."No.";
        ReconciliationBuffer.Description      := BankAcc.Name;
        ReconciliationBuffer."Amount LCY" := BankAcc."Net Change (LCY)";;
        ReconciliationBuffer."Currency Amount" := BankAcc."Net Change";
        ReconciliationBuffer."Currency Code" := BankAcc."Currency Code";
        ReconciliationBuffer.Blocked := BankAcc.Blocked;
        IF BankAcc."Currency Code" <> '' THEN
           ReconciliationBuffer."Foreign Currency Code" := BankAcc."Currency Code"
        ELSE
          ReconciliationBuffer."Currency Code" := GeneralLedgerSetup."LCY Code";
        ReconciliationBuffer.Type := 'Balance_Subledger_BankAcc';
        ReconciliationBuffer.No := BankAcc."No.";
        ReconciliationBuffer.DateFilter := l_DateFilter;
        ReconciliationBuffer.NoFilter := HJ_NoFilter;
        ReconciliationBuffer.Insert();

      UNTIL BankAcc.Next() = 0;

      Fill_Out_TempBlob(BankAcc.GETFILTERS);
      WebServiceLog.Update_log_With_Reply_DT(HJ_GUID, TempBlob);

      EXIT(TRUE);

    END;

    procedure GetTempData(var rec : Record 82210 temporary);
    BEGIN
      ReconciliationBuffer.Reset();
      IF NOT ReconciliationBuffer.Findset() THEN
        EXIT;
      REPEAT
        rec := ReconciliationBuffer;
        rec.INSERT(FALSE);
      UNTIL ReconciliationBuffer.Next() = 0;
    END;

    local procedure Fill_Out_TempBlob(p_Filter : Text);
    BEGIN
      CLEAR(TempBlob);
      TempBlob.Blob.CREATEOUTSTREAM(OutStr, TEXTENCODING::UTF8);
      OutStr.WRITETEXT(FORMAT('Company...........: '+ CompanyName())+
                       FORMAT(CR)+FORMAT(LF)+
                       FORMAT('Entry_Filters.....: '+ p_Filter)+
                       FORMAT(CR)+FORMAT(LF)+
                       FORMAT('Req DateFilter....: '+ HJ_DateFIlter)+
                       FORMAT(CR)+FORMAT(LF)+
                       FORMAT('Req NoFilter.: '+ HJ_NoFilter)+
                       FORMAT(CR)+FORMAT(LF)+
                       FORMAT('Records returned..: '+ FORMAT(ReconciliationBuffer.Count())));
    END;
    
}