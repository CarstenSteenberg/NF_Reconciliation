codeunit 50500 "Reconciliation Generate Data"
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
        GeneralLedgerSetup: Record "General Ledger Setup";
        ReconciliationBuffer: Record "Reconciliation Buffer" temporary;
        TempBlob: codeunit "Temp Blob";
        OutStr: OutStream;
        CR: Char;
        LF: Char;
        HJ_DateFIlter: Text[30];
        HJ_NoFilter: Text[250];
        WebServiceLog: Record "Web Service Log";

    procedure Extract_Match_Items(p_ReconParmBuffer: Record "Reconciliation Parm Buffer");
    var
        GLEntry: Record "G/L Entry";
        BTReconGLOutboundEntry: Record "Recon. G/L Outbound Entry";
        GLAccount: Record "G/L Account";
        Send: Boolean;
        BTNAVOutboundData: Record Outbound_Data;
        Last_Full_Guid: GUID;
        Last_Entry_No: Integer;
        Last_Incr_Guid: GUID;
        i: Integer;
    BEGIN
        CLEAR(GLAccount);
        //GLAccount.SETRANGE("Blackline Match", TRUE);
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

                    GLEntry.CALCFIELDS("Remaining Amount");

                    IF Send = TRUE THEN BEGIN

                        CLEAR(BTReconGLOutboundEntry);
                        BTReconGLOutboundEntry.INIT;
                        i += 1;
                        BTReconGLOutboundEntry."Entry No." := i;
                        BTReconGLOutboundEntry."Inserted By" := UserId();
                        BTReconGLOutboundEntry.Status := BTReconGLOutboundEntry.Status::Open;
                        BTReconGLOutboundEntry.CompanyID := CompanyName();
                        BTReconGLOutboundEntry."Inserted Date/Time" := CurrentDateTime();

                        BTReconGLOutboundEntry."G/L Account No." := GLEntry."G/L Account No.";
                        BTReconGLOutboundEntry."Posting Date" := GLEntry."Posting Date";

                        IF isDirtyText(GLEntry.Description) THEN
                            BTReconGLOutboundEntry.Description := cleanRow(GLEntry.Description)
                        ELSE
                            BTReconGLOutboundEntry.Description := GLEntry.Description;

                        BTReconGLOutboundEntry.Amount := GLEntry.Amount;
                        BTReconGLOutboundEntry."IC Partner Code" := GLEntry."IC Partner Code";
                        BTReconGLOutboundEntry."Remaining Amount" := GLEntry."Remaining Amount";
                        BTReconGLOutboundEntry."G/L Entry No." := GLEntry."Entry No.";
                        BTReconGLOutboundEntry."Creation Date" := DT2Date(GLEntry.SystemCreatedAt);
                        BTReconGLOutboundEntry."Document No." := GLEntry."Document No.";

                        IF isDirtyText(GLEntry."External Document No.") THEN
                            BTReconGLOutboundEntry."External Document No." := cleanRow(GLEntry."External Document No.")
                        ELSE
                            BTReconGLOutboundEntry."External Document No." := GLEntry."External Document No.";

                        BTReconGLOutboundEntry."Currency Code" := GeneralLedgerSetup."LCY Code";
                        BTReconGLOutboundEntry."Global Dimension 1 Code" := GLEntry."Global Dimension 1 Code";

                        IF BTReconGLOutboundEntry."Posting Date" > CALCDATE('<-CM-1D>', WorkDate()) THEN
                            BTReconGLOutboundEntry."Open Date" := BTReconGLOutboundEntry."Posting Date"
                        ELSE
                            BTReconGLOutboundEntry."Open Date" := CALCDATE('<-CM-1D>', WorkDate());

                        BTReconGLOutboundEntry."Extraction Type" := p_ReconParmBuffer."Extraction Type";
                        BTReconGLOutboundEntry."Execution Mode" := p_ReconParmBuffer."Execution Mode";
                        BTReconGLOutboundEntry.Batch_Guid := p_ReconParmBuffer.GUID;
                        BTReconGLOutboundEntry."Export Date/Time" := CURRENTDATETIME();

                        BTReconGLOutboundEntry.INSERT;
                    END;
                UNTIL GLEntry.Next() = 0;
            END;
        UNTIL GLAccount.Next() = 0;
        //<NF> #3593734  Filudtræk til Blackline afstemning
    END;

    local procedure Extract_Open_Items(p_ReconParmBuffer: Record "Reconciliation Parm Buffer");
    var
        GLEntry: Record "G/L Entry";
        BTReconGLOutboundEntry: Record "Recon. G/L Outbound Entry";
        GLAccount: Record "G/L Account";
        Send: Boolean;
        BTNAVOutboundData: Record Outbound_Data;
        Last_Full_Guid: GUID;
        Last_Entry_No: Integer;
        Last_Incr_Guid: GUID;
        i: Integer;
    BEGIN
        CLEAR(GLAccount);
        GLAccount.SETRANGE(reconciliation, TRUE);
        GLAccount.SETRANGE("Income/Balance", GLAccount."Income/Balance"::"Balance Sheet");
        GLAccount.SETRANGE(reconciliationopenitems, TRUE);
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
            GLEntry.SETFILTER("Date Filter", '..%1', CALCDATE('<-CM-1D>', WORKDATE()));

            //Write_Debug_Info('Incr.:'+FORMAT(Last_Incr_Guid));

            IF GLEntry.Findset() THEN BEGIN
                REPEAT
                    Send := TRUE;

                    GLEntry.CALCFIELDS("Remaining Amount");
                    IF p_ReconParmBuffer."Execution Mode" = p_ReconParmBuffer."Execution Mode"::Full THEN BEGIN
                        IF GLEntry."Remaining Amount" = 0 THEN
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
                        IF (NOT BTReconGLOutboundEntry.Findfirst()) AND (GLEntry."Remaining Amount" <> 0) THEN
                            Send := TRUE;

                        //If amount in the entry is different from the amount in the last full load - it is sent..
                        IF Send = FALSE THEN BEGIN
                            IF BTReconGLOutboundEntry.Findfirst() THEN
                                IF GLEntry."Remaining Amount" <> BTReconGLOutboundEntry."Remaining Amount" THEN
                                    Send := TRUE;
                        END;

                        //If the entry is new compared to last full load and remaining amount is <> 0 - it is sent..
                        IF Send = FALSE THEN BEGIN
                            IF (GLEntry."Entry No." > Last_Entry_No) AND (GLEntry."Remaining Amount" <> 0) THEN
                                Send := TRUE;
                        END;

                        BTReconGLOutboundEntry.SETCURRENTKEY("Extraction Type", "Execution Mode", "G/L Entry No.");
                        BTReconGLOutboundEntry.SETRANGE(Batch_Guid);
                        BTReconGLOutboundEntry.SETRANGE("Execution Mode", BTReconGLOutboundEntry."Execution Mode"::Incremental);
                        IF BTReconGLOutboundEntry.Findlast() THEN BEGIN
                            IF GLEntry."Remaining Amount" <> BTReconGLOutboundEntry."Remaining Amount" THEN
                                Send := TRUE
                            ELSE
                                Send := FALSE;
                        END;

                    END;

                    IF Send = TRUE THEN BEGIN
                        Clear(BTReconGLOutboundEntry);
                        BTReconGLOutboundEntry.Init();

                        i += 1;

                        BTReconGLOutboundEntry."Entry No." := i;
                        BTReconGLOutboundEntry.Status := BTReconGLOutboundEntry.Status::Open;
                        BTReconGLOutboundEntry.CompanyID := CompanyName();

                        BTReconGLOutboundEntry."G/L Account No." := GLEntry."G/L Account No.";
                        BTReconGLOutboundEntry."Posting Date" := GLEntry."Posting Date";
                        BTReconGLOutboundEntry.Description := CleanRow(GLEntry.Description);
                        BTReconGLOutboundEntry.Amount := GLEntry.Amount;
                        BTReconGLOutboundEntry."IC Partner Code" := GLEntry."IC Partner Code";
                        BTReconGLOutboundEntry."Remaining Amount" := GLEntry."Remaining Amount";
                        BTReconGLOutboundEntry."G/L Entry No." := GLEntry."Entry No.";
                        BTReconGLOutboundEntry."Creation Date" := DT2Date(GLEntry.SystemCreatedAt);
                        BTReconGLOutboundEntry."Document No." := GLEntry."Document No.";
                        BTReconGLOutboundEntry."External Document No." :=
                            CopyStr(CleanRow(GLEntry."External Document No."), 1, MaxStrLen(BTReconGLOutboundEntry."External Document No."));
                        BTReconGLOutboundEntry."Currency Code" := GeneralLedgerSetup."LCY Code";
                        BTReconGLOutboundEntry."Global Dimension 1 Code" := GLEntry."Global Dimension 1 Code";

                        IF BTReconGLOutboundEntry."Posting Date" > CALCDATE('<-CM-1D>', WORKDATE) THEN
                            BTReconGLOutboundEntry."Open Date" := BTReconGLOutboundEntry."Posting Date"
                        ELSE
                            BTReconGLOutboundEntry."Open Date" := CALCDATE('<-CM-1D>', WORKDATE);

                        BTReconGLOutboundEntry."Extraction Type" := p_ReconParmBuffer."Extraction Type";
                        BTReconGLOutboundEntry."Execution Mode" := p_ReconParmBuffer."Execution Mode";
                        BTReconGLOutboundEntry.Batch_Guid := p_ReconParmBuffer.GUID;
                        BTReconGLOutboundEntry."Export Date/Time" := CurrentDateTime();

                        BTReconGLOutboundEntry.Insert(true);
                    END;
                UNTIL GLEntry.Next() = 0;
            END;
        UNTIL GLAccount.Next() = 0;
    END;

    local procedure Extract_BankAcc(p_ReconParmBuffer: Record "Reconciliation Parm Buffer");
    var
        BankAccount: Record "Bank Account";
        BTReconMasterOutbEntry: Record "Recon Master Outb. Entry";
        BankAccountPostingGroup: Record "Bank Account Posting Group";
        i: Integer;
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
            i += 1;

            BTReconMasterOutbEntry.Init();
            BTReconMasterOutbEntry."Entry No." := i;
            BTReconMasterOutbEntry.Status := BTReconMasterOutbEntry.Status::Open;
            BTReconMasterOutbEntry.CompanyID := CompanyName();

            BTReconMasterOutbEntry."No." := BankAccount."No.";
            BTReconMasterOutbEntry.Name := CleanRow(BankAccount.Name);
            BTReconMasterOutbEntry.Balance := BankAccount."Net Change";
            BTReconMasterOutbEntry."Balance (LCY)" := BankAccount."Net Change (LCY)";

            if BankAccountPostingGroup.Get(BankAccount."Bank Acc. Posting Group") then
                BTReconMasterOutbEntry."G/L Account" :=
                    BankAccountPostingGroup."G/L Account No.";

            BTReconMasterOutbEntry.Type := BTReconMasterOutbEntry.Type::Bank;
            BTReconMasterOutbEntry.Currency := BankAccount."Currency Code";

            if BTReconMasterOutbEntry.Currency = '' then
                BTReconMasterOutbEntry.Currency := GeneralLedgerSetup."LCY Code";

            BTReconMasterOutbEntry."Last Date of the period" :=
                CalcDate('<-CM-1D>', WorkDate());

            BTReconMasterOutbEntry."Extraction Type" :=
                p_ReconParmBuffer."Extraction Type";
            BTReconMasterOutbEntry."Execution Mode" :=
                p_ReconParmBuffer."Execution Mode";
            BTReconMasterOutbEntry.Batch_Guid := p_ReconParmBuffer.GUID;
            ;
            BTReconMasterOutbEntry."Export Date/Time" := CurrentDateTime();

            BTReconMasterOutbEntry.Insert(true);
        UNTIL BankAccount.Next() = 0;
    END;

    local procedure Extract_Customer(p_ReconParmBuffer: Record "Reconciliation Parm Buffer");
    var
        Customer: Record 18;
        BTReconMasterOutbEntry: Record "Recon Master Outb. Entry";
        CustomerPostingGroup: Record "Customer Posting Group";
        Last_Full_Guid: GUID;
        Last_Incr_Guid: GUID;
        i: Integer;
        Send: Boolean;
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

            if Send then begin
                i += 1;

                BTReconMasterOutbEntry.Init();
                BTReconMasterOutbEntry."Entry No." := i;
                BTReconMasterOutbEntry.Status := BTReconMasterOutbEntry.Status::Open;
                BTReconMasterOutbEntry.CompanyID := CompanyName();

                BTReconMasterOutbEntry."No." := Customer."No.";
                BTReconMasterOutbEntry.Name := CleanRow(Customer.Name);
                BTReconMasterOutbEntry.Balance := Customer."Net Change";
                BTReconMasterOutbEntry."Balance (LCY)" := Customer."Net Change (LCY)";

                Clear(CustomerPostingGroup);
                if CustomerPostingGroup.Get(Customer."Customer Posting Group") then
                    BTReconMasterOutbEntry."G/L Account" :=
                        CustomerPostingGroup."Receivables Account";

                BTReconMasterOutbEntry.Type := BTReconMasterOutbEntry.Type::Customer;
                BTReconMasterOutbEntry.Currency := GeneralLedgerSetup."LCY Code";
                BTReconMasterOutbEntry."Last Date of the period" :=
                    CalcDate('<-CM-1D>', WorkDate());

                BTReconMasterOutbEntry."Extraction Type" :=
                    p_ReconParmBuffer."Extraction Type";
                BTReconMasterOutbEntry."Execution Mode" :=
                    p_ReconParmBuffer."Execution Mode";
                BTReconMasterOutbEntry.Batch_Guid := p_ReconParmBuffer.GUID;
                BTReconMasterOutbEntry."Export Date/Time" := CurrentDateTime();

                BTReconMasterOutbEntry.Insert(true);
            end;
        UNTIL Customer.Next() = 0;
    END;

    local procedure Extract_Vendor(p_ReconParmBuffer: Record "Reconciliation Parm Buffer");
    var
        Vendor: Record 23;
        BTReconMasterOutbEntry: Record "Recon Master Outb. Entry";
        VendorPostingGroup: Record "Vendor Posting Group";
        Last_Full_Guid: GUID;
        Last_Incr_Guid: GUID;
        i: Integer;
        Send: Boolean;
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
                        IF (Vendor."Net Change (LCY)" * -1) <> BTReconMasterOutbEntry."Balance (LCY)" THEN
                            Send := TRUE;
                END;

                //IF entry exist in the last incremental load and amount has changed, it is sent - if not it is NOT sent..
                BTReconMasterOutbEntry.SETRANGE(Batch_Guid, Last_Incr_Guid);
                IF BTReconMasterOutbEntry.Findfirst() THEN BEGIN
                    IF (Vendor."Net Change (LCY)" * -1) <> BTReconMasterOutbEntry."Balance (LCY)" THEN
                        Send := TRUE
                    ELSE
                        Send := FALSE;
                END;
            END;
            if Send then begin
                i += 1;

                BTReconMasterOutbEntry.Init();
                BTReconMasterOutbEntry."Entry No." := i;
                BTReconMasterOutbEntry.Status := BTReconMasterOutbEntry.Status::Open;
                BTReconMasterOutbEntry.CompanyID := CompanyName();

                BTReconMasterOutbEntry."No." := Vendor."No.";
                BTReconMasterOutbEntry.Name := CleanRow(Vendor.Name);
                BTReconMasterOutbEntry.Balance := -Vendor."Net Change";
                BTReconMasterOutbEntry."Balance (LCY)" := -Vendor."Net Change (LCY)";

                Clear(VendorPostingGroup);
                if VendorPostingGroup.Get(Vendor."Vendor Posting Group") then
                    BTReconMasterOutbEntry."G/L Account" :=
                        VendorPostingGroup."Payables Account";

                BTReconMasterOutbEntry.Type := BTReconMasterOutbEntry.Type::Vendor;
                BTReconMasterOutbEntry.Currency := GeneralLedgerSetup."LCY Code";
                BTReconMasterOutbEntry."Last Date of the period" :=
                    CalcDate('<-CM-1D>', WorkDate());

                BTReconMasterOutbEntry."Extraction Type" :=
                    p_ReconParmBuffer."Extraction Type";
                BTReconMasterOutbEntry."Execution Mode" :=
                    p_ReconParmBuffer."Execution Mode";
                BTReconMasterOutbEntry.Batch_Guid := p_ReconParmBuffer.GUID;
                BTReconMasterOutbEntry."Export Date/Time" := CurrentDateTime();

                BTReconMasterOutbEntry.Insert(true);
            end;

        UNTIL Vendor.Next() = 0;
    END;

    local procedure Extract_GLAcc(p_ReconParmBuffer: Record "Reconciliation Parm Buffer");
    var
        GLAccount: Record "G/L Account";
        BTReconMasterOutbEntry: Record "Recon Master Outb. Entry";
        GeneralLedgerSetup: Record "General Ledger Setup";
        GLEntry: Record "G/L Entry";
        i: Integer;
    BEGIN
        CLEAR(GLAccount);
        GLAccount.SETRANGE("Account Type", GLAccount."Account Type"::Posting);
        GLAccount.SETRANGE(reconciliation, TRUE);
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
            GLEntry.SETFILTER("Posting Date", '%1..%2', CALCDATE('-CM-1M', WORKDATE()), CALCDATE('<-CM-1D>', WORKDATE()));


            GLAccount.CALCFIELDS("Balance at Date");
            i += 1;

            BTReconMasterOutbEntry.Init();
            BTReconMasterOutbEntry."Entry No." := i;
            BTReconMasterOutbEntry.Status := BTReconMasterOutbEntry.Status::Open;
            BTReconMasterOutbEntry.CompanyID := CompanyName();

            BTReconMasterOutbEntry."No." := GLAccount."No.";
            BTReconMasterOutbEntry.Name := CleanRow(GLAccount.Name);
            BTReconMasterOutbEntry.Balance := GLAccount."Balance at Date";
            BTReconMasterOutbEntry.Currency := GeneralLedgerSetup."LCY Code";

            if GLAccount.reconciliation = FALSE then
                BTReconMasterOutbEntry."Active Account" := 'FALSE'
            else
                BTReconMasterOutbEntry."Active Account" := 'TRUE';

            if GLEntry.IsEmpty() then
                BTReconMasterOutbEntry."Any Activity in period" := 'FALSE'
            else
                BTReconMasterOutbEntry."Any Activity in period" := 'TRUE';

            BTReconMasterOutbEntry."Last Date of the period" :=
                CalcDate('<-CM-1D>', WorkDate());

            BTReconMasterOutbEntry."Extraction Type" :=
                p_ReconParmBuffer."Extraction Type";
            BTReconMasterOutbEntry."Execution Mode" :=
                p_ReconParmBuffer."Execution Mode";
            BTReconMasterOutbEntry.Batch_Guid := p_ReconParmBuffer.GUID;
            BTReconMasterOutbEntry."Export Date/Time" := CurrentDateTime();

            BTReconMasterOutbEntry.Insert(true);
        UNTIL GLAccount.Next() = 0;
    END;

    local procedure Extract_IC(p_ReconParmBuffer: Record "Reconciliation Parm Buffer"; var p_GLAccount: Record 15);
    var
        BTReconGLOutboundEntry: Record "Recon. G/L Outbound Entry";
        Send: Boolean;
        BTNAVOutboundData: Record Outbound_Data;
        Last_Full_Guid: GUID;
        Last_Entry_No: Integer;
        Last_Incr_Guid: GUID;
        i: Integer;
        GL_Account_Int: Integer;
        GLEntry: Record "G/L Entry";
        GeneralLedgerSetup: Record "General Ledger Setup";
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
            GLEntry.SETFILTER("Document No.", '<>@*EXCH*');

            IF DATE2DMY(WorkDate(), 1) < 19 THEN
                GLEntry.SETRANGE("Posting Date", CALCDATE('-CM', CALCDATE('-CM-1D', WorkDate())), CALCDATE('CM', CALCDATE('-CM-1D', WorkDate())))
            ELSE
                GLEntry.SETRANGE("Posting Date", CALCDATE('-CM', WorkDate()), CALCDATE('CM', WorkDate()));

            IF GLEntry.Findset() THEN BEGIN
                REPEAT
                    Send := TRUE;
                    //Write_Debug_Info(GLEntry.GETFILTERS);
                    GLEntry.CALCFIELDS("Remaining Amount");
                    if Send then begin
                        Clear(BTReconGLOutboundEntry);
                        BTReconGLOutboundEntry.Init();

                        i += 1;

                        BTReconGLOutboundEntry."Entry No." := i;
                        BTReconGLOutboundEntry.Status := BTReconGLOutboundEntry.Status::Open;
                        BTReconGLOutboundEntry.CompanyID := CompanyName();

                        BTReconGLOutboundEntry."G/L Account No." := GLEntry."G/L Account No.";
                        BTReconGLOutboundEntry."Posting Date" := GLEntry."Posting Date";
                        BTReconGLOutboundEntry.Description := CleanRow(GLEntry.Description);

                        BTReconGLOutboundEntry."Currency Code" := GeneralLedgerSetup."LCY Code";
                        BTReconGLOutboundEntry.Amount := GLEntry.Amount;

                        BTReconGLOutboundEntry."Foreign Currency Code" :=
                            GLEntry."Source Currency Code";
                        BTReconGLOutboundEntry."Currency Amount" :=
                            GLEntry."Source Currency Amount";

                        if (BTReconGLOutboundEntry."Foreign Currency Code" = '') or
                           (BTReconGLOutboundEntry."Foreign Currency Code" =
                            BTReconGLOutboundEntry."Currency Code")
                        then begin
                            BTReconGLOutboundEntry."Foreign Currency Code" :=
                                BTReconGLOutboundEntry."Currency Code";
                            BTReconGLOutboundEntry."Currency Amount" :=
                                BTReconGLOutboundEntry.Amount;
                        end;

                        BTReconGLOutboundEntry."Remaining Amount" :=
                            BTReconGLOutboundEntry.Amount;

                        BTReconGLOutboundEntry."IC Partner Code" :=
                            GLEntry."IC Partner Code";

                        if BTReconGLOutboundEntry."IC Partner Code" = 'TRE1' then
                            BTReconGLOutboundEntry."IC Partner Code" := 'TRE';

                        BTReconGLOutboundEntry."G/L Entry No." := GLEntry."Entry No.";
                        BTReconGLOutboundEntry."Creation Date" := DT2Date(GLEntry.SystemCreatedAt);
                        BTReconGLOutboundEntry."Document No." := GLEntry."Document No.";
                        BTReconGLOutboundEntry."Document Date" := GLEntry."Document Date";

                        BTReconGLOutboundEntry."Source No." := GLEntry."Source No.";

                        if BTReconGLOutboundEntry."Source No." = 'TRE1' then
                            BTReconGLOutboundEntry."Source No." := 'TRE';

                        if GLEntry."Source Type" <> GLEntry."Source Type"::" " then
                            BTReconGLOutboundEntry."Source Type" :=
                                Format(GLEntry."Source Type");

                        if GLEntry."Document Type" <> GLEntry."Document Type"::" " then
                            BTReconGLOutboundEntry."Document Type" :=
                                Format(GLEntry."Document Type");

                        BTReconGLOutboundEntry."External Document No." :=
                            CopyStr(
                                CleanRow(GLEntry."External Document No."),
                                1,
                                MaxStrLen(BTReconGLOutboundEntry."External Document No."));

                        BTReconGLOutboundEntry."Global Dimension 1 Code" :=
                            GLEntry."Global Dimension 1 Code";

                        IF BTReconGLOutboundEntry."Posting Date" > CALCDATE('<-CM-1D>', WORKDATE) THEN
                            BTReconGLOutboundEntry."Open Date" := BTReconGLOutboundEntry."Posting Date"
                        ELSE
                            BTReconGLOutboundEntry."Open Date" := CALCDATE('<-CM-1D>', WORKDATE);

                        if GLEntry.Open then
                            BTReconGLOutboundEntry.Closed := 'FALSE'
                        else
                            BTReconGLOutboundEntry.Closed := 'TRUE';

                        BTReconGLOutboundEntry."Extraction Type" :=
                            p_ReconParmBuffer."Extraction Type";
                        BTReconGLOutboundEntry."Execution Mode" :=
                            BTReconGLOutboundEntry."Execution Mode"::Full;
                        BTReconGLOutboundEntry.Batch_Guid :=
                            p_ReconParmBuffer.GUID;
                        BTReconGLOutboundEntry."Export Date/Time" :=
                            CurrentDateTime();

                        BTReconGLOutboundEntry.Insert(true);
                    end;

                UNTIL GLEntry.Next() = 0;
            END;
        UNTIL p_GLAccount.Next() = 0;
        //</NF> #6231548  Blackline IC Partner filer fra NAV
    END;

    local procedure Extract_IC_ACC(p_ReconParmBuffer: Record "Reconciliation Parm Buffer");
    var
        GLAccount: Record "G/L Account";
    BEGIN
        CLEAR(GLAccount);
        GLAccount.SETFILTER("No.", '843030|935140');
        Extract_IC(p_ReconParmBuffer, GLAccount);

    END;

    local procedure Extract_IC_BAL(p_ReconParmBuffer: Record "Reconciliation Parm Buffer");
    var
        GLAccount: Record "G/L Account";
        BTReconMasterOutbEntry: Record "Recon Master Outb. Entry";
    BEGIN
        //<NF> #6231548  Blackline IC Partner filer fra NAV
        CLEAR(GLAccount);
        GLAccount.SETFILTER("No.", '843010|846535|933230|935110');
        Extract_IC(p_ReconParmBuffer, GLAccount);
        //</NF> #6231548  Blackline IC Partner filer fra NAV
    END;

    local procedure Extract_IC_FIN(p_ReconParmBuffer: Record "Reconciliation Parm Buffer");
    var
        GLAccount: Record 15;
        BTReconMasterOutbEntry: Record "Recon Master Outb. Entry";
    BEGIN
        //<NF> #6231548  Blackline IC Partner filer fra NAV
        CLEAR(GLAccount);
        GLAccount.SETFILTER("No.", '821010|843020|843022|924010|924020|935210|935220|935112');
        Extract_IC(p_ReconParmBuffer, GLAccount);

    END;

    local procedure Extract_IC_FV(p_ReconParmBuffer: Record "Reconciliation Parm Buffer");
    var
        GLAccount: Record "G/L Account";
        BTReconMasterOutbEntry: Record "Recon Master Outb. Entry";
    BEGIN
        //<NF> #6231548  Blackline IC Partner filer fra NAV
        CLEAR(GLAccount);
        GLAccount.SETFILTER("No.", '735300..735399|751000..751199|751211..751999');
        Extract_IC(p_ReconParmBuffer, GLAccount);
        //</NF> #6231548  Blackline IC Partner filer fra NAV
    END;

    local procedure Extract_IC_INT(p_ReconParmBuffer: Record "Reconciliation Parm Buffer");
    var
        GLAccount: Record 15;
        BTReconMasterOutbEntry: Record "Recon Master Outb. Entry";
    BEGIN
        //<NF> #6231548  Blackline IC Partner filer fra NAV
        CLEAR(GLAccount);
        GLAccount.SETFILTER("No.", '723000..723999|735200..735299|743000..743999|751210');
        Extract_IC(p_ReconParmBuffer, GLAccount);
        //</NF> #6231548  Blackline IC Partner filer fra NAV
    END;

    local procedure Extract_IC_Pnl(p_ReconParmBuffer: Record "Reconciliation Parm Buffer");
    var
        GLAccount: Record 15;
        BTReconMasterOutbEntry: Record "Recon Master Outb. Entry";
    BEGIN
        //<NF> #6231548  Blackline IC Partner filer fra NAV
        CLEAR(GLAccount);
        GLAccount.SETFILTER("No.", '1..255999|265000..265999|281000..281999|285000..285999|295000..295999|' +
                                  '360000..369998|375000..375999|385000..385999|395000..395999|' +
                                  '405000..405999|410000..410999|415000..499999|' +
                                  '515000..516999|545000..545999|550000..550999|555000..585999|' +
                                  '619000..632999|636000..636999|642000..642999|646000..646999|' +
                                  //<NF> #7658430  FW: Mapping 205210 og 205215
                                  //'702000..702999|775010');
                                  '702000..702999|775010&<>205210&<>205215');
        //</NF> #7658430  FW: Mapping 205210 og 205215

        Extract_IC(p_ReconParmBuffer, GLAccount);
        //</NF> #6231548  Blackline IC Partner filer fra NAV
    END;

    local procedure isDirtyText(textValue: Text): Boolean;
    var
        CR: Text[1];
        LF: Text[1];
        TAB: Text[1];
    BEGIN
        CR[1] := 13;
        LF[1] := 10;
        TAB[1] := 9;
        EXIT(NOT ((STRPOS(textValue, CR) = 0) AND (STRPOS(textValue, LF) = 0) AND (STRPOS(textValue, TAB) = 0)));
    END;

    local procedure cleanRow(sourceText: Text): Text;
    var
        destinationText: Text;
        CR: Integer;
        LF: Integer;
        TAB: Integer;
        dp: Integer;
        sp: Integer;
        textInteger: Integer;
        rowChanged: Boolean;
    BEGIN
        CR := 13;
        LF := 10;
        TAB := 9;
        dp := 0;
        destinationText := '';
        FOR sp := 1 TO STRLEN(sourceText) DO BEGIN
            textInteger := sourceText[sp];
            CASE textInteger OF
                CR:
                    BEGIN
                        rowChanged := TRUE;
                    END;
                LF:
                    BEGIN
                        rowChanged := TRUE;
                    END;
                TAB:
                    BEGIN
                        rowChanged := TRUE;
                    END;
                ELSE
                    dp += 1;
                    destinationText[dp] := sourceText[sp];
            END;
        END;
        EXIT(destinationText);
    END;

    procedure TestDirtyText();
    var
        t: Text;
        CR: Char;
        LF: Char;
        TAB: Text[1];
    BEGIN
        LF := 10;
        CR := 13;
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

    /*
    local procedure Write_Debug_Info(p: Text[100]);
    var
        EntryBuffer: Record entry b;
        i: Integer;
    BEGIN
        i := 1;
        IF EntryBuffer.Findlast() THEN
            i := EntryBuffer."Entry No.";
        EntryBuffer.Init();
        EntryBuffer."Entry No." := i + 1;
        EntryBuffer.Description := p;
        EntryBuffer.Insert();
    END;
    */

    procedure TempGLEntryDataGeneratedOK(var p_Filter_Rec: Record "Reconciliation Buffer"): Boolean;
    var
        FilterTokens: Codeunit "Filter Tokens";
        i: Integer;
        l_DateFilter: Text[30];
        HJ_DT: DateTime;
        HJ_GUID: GUID;
        GeneralLedgerSetup: Record "General Ledger Setup";
        GLAccount: Record "G/L Account";
        GLEntry: Record "G/L Entry";
    BEGIN
        HJ_DT := CURRENTDATETIME();
        HJ_GUID := CREATEGUID();

        WebServiceLog.InsertLog('WS Reconciliation GLEntry', HJ_GUID, HJ_DT, 1);

        //Init_Execution();
        GeneralLedgerSetup.GET();

        CLEAR(GLAccount);
        //GLAccount.SETRANGE("Blackline Not included", FALSE);
        GLAccount.SETRANGE("Income/Balance", GLAccount."Income/Balance"::"Balance Sheet");
        GLAccount.SETRANGE(ReconciliationOpenItems, TRUE);
        GLAccount.SETRANGE("Account Type", GLAccount."Account Type"::Posting);

        l_DateFilter := DELCHR(p_Filter_Rec.GETFILTER(DateFilter), '=', '''');
        HJ_NoFilter := DELCHR(p_Filter_Rec.GETFILTER(NoFilter), '=', '''');
        HJ_DateFIlter := l_DateFilter;

        IF l_DateFilter = '' THEN
            l_DateFilter := STRSUBSTNO('..%1', CALCDATE('<-CM-1D>', WORKDATE()));

        FilterTokens.MakeDateFilter(l_DateFilter);

        IF HJ_NoFilter <> '' THEN
            GLAccount.SETFILTER("No.", HJ_NoFilter);

        IF NOT GLAccount.Findset() THEN BEGIN
            Fill_Out_TempBlob(GLAccount.GETFILTERS);
            WebServiceLog.UpdatelogWithReplyDT(HJ_GUID, TempBlob);
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
                    GLEntry.SETFILTER("Date Filter", l_DateFilter);
                    GLEntry.CALCFIELDS("Remaining Amount");
                    IF GLEntry."Remaining Amount" <> 0 THEN BEGIN
                        ReconciliationBuffer.Init();
                        i += 1;
                        ReconciliationBuffer."Entry No." := i;
                        ReconciliationBuffer.CompanyID := CompanyName();
                        ReconciliationBuffer.GL_Account_No := GLAccount."No.";
                        ReconciliationBuffer.Description := GLEntry.Description;
                        ReconciliationBuffer."Posting Date" := FORMAT(GLEntry."Posting Date", 0, '<day,2>-<Month,2>-<Year4>');
                        ReconciliationBuffer."Amount LCY" := GLEntry.Amount;
                        ReconciliationBuffer."IC Partner Code" := GLEntry."IC Partner Code";
                        ReconciliationBuffer.Department := GLEntry."Global Dimension 1 Code";
                        ReconciliationBuffer.GL_Entry_No := GLEntry."Entry No.";
                        ReconciliationBuffer."Document No." := GLEntry."Document No.";
                        ReconciliationBuffer."Creation Date" := FORMAT(GLEntry.SystemCreatedAt, 0, '<day,2>-<Month,2>-<Year4>');
                        ReconciliationBuffer."External Document No." := GLEntry."External Document No.";
                        ReconciliationBuffer."Currency Code" := GeneralLedgerSetup."LCY Code";
                        ReconciliationBuffer."Remaining Amount" := GLEntry."Remaining Amount";
                        ReconciliationBuffer.DateFilter := l_DateFilter;
                        ReconciliationBuffer.NoFilter := HJ_NoFilter;
                        ReconciliationBuffer.Insert();
                    END;
                UNTIL GLEntry.Next() = 0;
            END;
        UNTIL GLAccount.Next() = 0;

        Fill_Out_TempBlob(GLAccount.GETFILTERS);
        WebServiceLog.UpdatelogWithReplyDT(HJ_GUID, TempBlob);

        EXIT(TRUE);

    END;

    procedure TempCustomerDataGeneratedOK(var p_Filter_Rec: Record "Reconciliation Buffer"): Boolean;
    var
        FilterTokens: Codeunit "Filter Tokens";
        i: Integer;
        l_DateFilter: Text[30];
        HJ_DT: DateTime;
        HJ_GUID: GUID;
        GeneralLedgerSetup: Record "General Ledger Setup";
        Customer: Record Customer;
        CustomerPostingGroup: Record "Customer Posting Group";
    BEGIN
        HJ_DT := CURRENTDATETIME();
        HJ_GUID := CREATEGUID();
        WebServiceLog.InsertLog('WS Reconciliation Customer', HJ_GUID, HJ_DT, 1);
        //Init_Execution();
        GeneralLedgerSetup.GET();

        CLEAR(Customer);

        l_DateFilter := DELCHR(p_Filter_Rec.GETFILTER(DateFilter), '=', '''');
        HJ_NoFilter := DELCHR(p_Filter_Rec.GETFILTER(NoFilter), '=', '''');

        FilterTokens.MakeDateFilter(l_DateFilter);

        IF l_DateFilter = '' THEN
            l_DateFilter := STRSUBSTNO('..%1', CALCDATE('<-CM-1D>', WORKDATE()));

        HJ_DateFIlter := l_DateFilter;

        IF HJ_NoFilter <> '' THEN
            Customer.SETFILTER("No.", HJ_NoFilter);

        IF NOT Customer.Findset() THEN BEGIN
            Fill_Out_TempBlob(Customer.GETFILTERS);
            WebServiceLog.UpdatelogWithReplyDT(HJ_GUID, TempBlob);
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
                ReconciliationBuffer.Description := Customer.Name;
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
        WebServiceLog.UpdatelogWithReplyDT(HJ_GUID, TempBlob);

        EXIT(TRUE);

    END;

    procedure TempVendorDataGeneratedOK(var p_Filter_Rec: Record "Reconciliation Buffer"): Boolean;
    var
        FilterTokens: Codeunit "Filter Tokens";
        i: Integer;
        l_DateFilter: Text[30];
        HJ_DT: DateTime;
        HJ_GUID: GUID;
        GeneralLedgerSetup: Record "General Ledger Setup";
        Vendor: Record Vendor;
        VendorPostingGroup: Record "Vendor Posting Group";
    BEGIN
        HJ_DT := CURRENTDATETIME();
        HJ_GUID := CREATEGUID();
        WebServiceLog.InsertLog('WS Reconciliation Vendor', HJ_GUID, HJ_DT, 1);
        //Init_Execution();
        GeneralLedgerSetup.GET();

        CLEAR(Vendor);

        l_DateFilter := DELCHR(p_Filter_Rec.GETFILTER(DateFilter), '=', '''');
        HJ_NoFilter := DELCHR(p_Filter_Rec.GETFILTER(NoFilter), '=', '''');

        FilterTokens.MakeDateFilter(l_DateFilter);

        IF l_DateFilter = '' THEN
            l_DateFilter := STRSUBSTNO('..%1', CALCDATE('<-CM-1D>', WORKDATE()));

        HJ_DateFIlter := l_DateFilter;

        IF HJ_NoFilter <> '' THEN
            Vendor.SETFILTER("No.", HJ_NoFilter);

        IF NOT Vendor.Findset() THEN BEGIN
            Fill_Out_TempBlob(Vendor.GETFILTERS);
            WebServiceLog.UpdatelogWithReplyDT(HJ_GUID, TempBlob);
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
                ReconciliationBuffer.Description := Vendor.Name;
                ReconciliationBuffer."Amount LCY" := Vendor."Net Change (LCY)" * -1;
                ReconciliationBuffer."Currency Code" := GeneralLedgerSetup."LCY Code";
                ReconciliationBuffer.Type := 'Balance_Subledger_Vendor';
                ReconciliationBuffer.No := Vendor."No.";
                ReconciliationBuffer.DateFilter := l_DateFilter;
                ReconciliationBuffer.NoFilter := HJ_NoFilter;
                ReconciliationBuffer.Insert();
            END;
        UNTIL Vendor.Next() = 0;

        Fill_Out_TempBlob(Vendor.GETFILTERS);
        WebServiceLog.UpdatelogWithReplyDT(HJ_GUID, TempBlob);

        EXIT(TRUE);

    END;

    procedure TempBankDataGeneratedOK(var p_Filter_Rec: Record "Reconciliation Buffer"): Boolean;
    var
        FilterTokens: Codeunit "Filter Tokens";
        i: Integer;
        l_DateFilter: Text[30];
        HJ_DT: DateTime;
        HJ_GUID: GUID;
        GeneralLedgerSetup: Record "General Ledger Setup";
        BankAcc: Record "Bank Account";
        BankPostingGroup: Record "Bank Account Posting Group";
    BEGIN
        HJ_DT := CURRENTDATETIME();
        HJ_GUID := CREATEGUID();
        WebServiceLog.InsertLog('WS Reconciliation BankAcc', HJ_GUID, HJ_DT, 1);
        GeneralLedgerSetup.GET();

        CLEAR(BankAcc);

        l_DateFilter := DELCHR(p_Filter_Rec.GETFILTER(DateFilter), '=', '''');
        HJ_NoFilter := DELCHR(p_Filter_Rec.GETFILTER(NoFilter), '=', '''');

        FilterTokens.MakeDateFilter(l_DateFilter);

        IF l_DateFilter = '' THEN
            l_DateFilter := STRSUBSTNO('..%1', CALCDATE('<-CM-1D>', WORKDATE()));

        HJ_DateFIlter := l_DateFilter;

        IF HJ_NoFilter <> '' THEN
            BankAcc.SETFILTER("No.", HJ_NoFilter);

        IF NOT BankAcc.Findset() THEN BEGIN
            Fill_Out_TempBlob(BankAcc.GETFILTERS);
            WebServiceLog.UpdatelogWithReplyDT(HJ_GUID, TempBlob);
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
                ReconciliationBuffer.GL_Account_No := BankPostingGroup."G/L Account No.";

            ReconciliationBuffer."Source No." := BankAcc."No.";
            ReconciliationBuffer.Description := BankAcc.Name;
            ReconciliationBuffer."Amount LCY" := BankAcc."Net Change (LCY)";
            ;
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
        WebServiceLog.UpdateLogWithReplyDT(HJ_GUID, TempBlob);

        EXIT(TRUE);

    END;

    procedure GetTempData(var rec: Record "Reconciliation Buffer" temporary);
    BEGIN
        ReconciliationBuffer.Reset();
        IF NOT ReconciliationBuffer.Findset() THEN
            EXIT;
        REPEAT
            rec := ReconciliationBuffer;
            rec.INSERT(FALSE);
        UNTIL ReconciliationBuffer.Next() = 0;
    END;

    local procedure Fill_Out_TempBlob(p_Filter: Text);
    BEGIN
        CLEAR(TempBlob);
        TempBlob.CREATEOUTSTREAM(OutStr, TEXTENCODING::UTF8);
        OutStr.WRITETEXT(FORMAT('Company...........: ' + CompanyName()) +
                         FORMAT(CR) + FORMAT(LF) +
                         FORMAT('Entry_Filters.....: ' + p_Filter) +
                         FORMAT(CR) + FORMAT(LF) +
                         FORMAT('Req DateFilter....: ' + HJ_DateFIlter) +
                         FORMAT(CR) + FORMAT(LF) +
                         FORMAT('Req NoFilter.: ' + HJ_NoFilter) +
                         FORMAT(CR) + FORMAT(LF) +
                         FORMAT('Records returned..: ' + FORMAT(ReconciliationBuffer.Count())));
    END;

    procedure CheckDateStatus(
    CalendarCode: Code[10];
    TargetDate: Date;
    var Description: Text[50]): Boolean
    var
        BaseCalChange: Record "Base Calendar Change";
    begin
        BaseCalChange.Reset();
        BaseCalChange.SetRange("Base Calendar Code", CalendarCode);

        if BaseCalChange.FindSet() then
            repeat
                case BaseCalChange."Recurring System" of
                    BaseCalChange."Recurring System"::" ":
                        if TargetDate = BaseCalChange.Date then begin
                            Description := BaseCalChange.Description;
                            exit(BaseCalChange.Nonworking);
                        end;

                    BaseCalChange."Recurring System"::"Weekly Recurring":
                        if Date2DWY(TargetDate, 1) = BaseCalChange.Day then begin
                            Description := BaseCalChange.Description;
                            exit(BaseCalChange.Nonworking);
                        end;

                    BaseCalChange."Recurring System"::"Annual Recurring":
                        if (Date2DMY(TargetDate, 2) = Date2DMY(BaseCalChange.Date, 2)) and
                           (Date2DMY(TargetDate, 1) = Date2DMY(BaseCalChange.Date, 1))
                        then begin
                            Description := BaseCalChange.Description;
                            exit(BaseCalChange.Nonworking);
                        end;
                end;
            until BaseCalChange.Next() = 0;

        Description := '';
        exit(false);
    end;

}