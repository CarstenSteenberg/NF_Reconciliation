codeunit 50501 "BlackLine File Creation"
{
    Subtype = Normal;

    trigger OnRun()
    begin
    end;

    var
        CR: Char;
        LF: Char;
        TAB: Char;
        OStream: OutStream;
        SemiKolon: Char;

    local procedure Init_Execution()
    begin
        LF := 10;
        CR := 13;
        TAB := 9;
        SemiKolon := 59;
        CLEAR(OStream);
    end;

    procedure Match_Items(var TempBlob: Codeunit "Temp Blob"; "p_Extraction Type": Option BlackLine_NF_BlackLine_Account_Items,BlackLine_Bank,BlackLine_Customer,BlackLine_GL_Account_Balance,BlackLine_Vendor,BlackLine_IC_ACC,BlackLine_IC_BAL,BlackLine_IC_FIN,BlackLine_IC_FV,BlackLine_IC_INT,BlackLine_IC_PnL,BlackLine_Match; p_Batch_Guid: GUID; p_Comp: Code[20]; p_Acc: Code[20])
    var
        ReconGLOutboundEntry: Record "Recon. G/L Outbound Entry";
        GLEntry: Record "G/L Entry";
        SourceType_txt: Text[20];
        DocumentType_txt: Text[20];
        CurrencyCode_Txt: Text[10];
        GeneralLedgerSetup: Record 98;
    begin
        Init_Execution();
        GeneralLedgerSetup.GET();

        TempBlob.CREATEOUTSTREAM(OStream, TEXTENCODING::UTF8);

        ReconGLOutboundEntry.SETCURRENTKEY(Batch_Guid, CompanyID, "G/L Account No.", "G/L Entry No.");
        ReconGLOutboundEntry.SETRANGE(Batch_Guid, p_Batch_Guid);
        ReconGLOutboundEntry.SETRANGE(CompanyID, p_Comp);
        ReconGLOutboundEntry.SETRANGE("G/L Account No.", p_Acc);

        if NOT ReconGLOutboundEntry.FINDSET then
            EXIT;

        repeat
            GLEntry.GET(ReconGLOutboundEntry."G/L Entry No.");

            DocumentType_txt := FORMAT(GLEntry."Document Type");
            if GLEntry."Document Type" = GLEntry."Document Type"::" " then
                DocumentType_txt := '';
            SourceType_txt := FORMAT(GLEntry."Source Type");
            if GLEntry."Source Type" = GLEntry."Source Type"::" " then
                SourceType_txt := '';
            CurrencyCode_Txt := GLEntry."Source Currency Code";
            if GLEntry."Source Currency Code" = '' then
                CurrencyCode_Txt := GeneralLedgerSetup."LCY Code";

            OStream.WRITETEXT(FORMAT(GLEntry."Posting Date", 0, '<day,2>-<Month,2>-<Year4>') + FORMAT(SemiKolon) +
                              FORMAT(DocumentType_txt) + FORMAT(SemiKolon) +
                              FORMAT(GLEntry."Document No.") + FORMAT(SemiKolon) +
                              FORMAT(GLEntry."External Document No.") + FORMAT(SemiKolon) +
                              FORMAT(GLEntry."G/L Account No.") + FORMAT(SemiKolon) +
                              FORMAT(GLEntry.Description) + FORMAT(SemiKolon) +
                              FORMAT(CurrencyCode_Txt) + FORMAT(SemiKolon) +
                              FORMAT(GLEntry."Source Currency Amount", 0, '<Sign><Integer><Decimals,21><Comma,.>') + FORMAT(SemiKolon) +
                              FORMAT(GLEntry.Amount, 0, '<Sign><Integer><Decimals,21><Comma,.>') + FORMAT(SemiKolon) +
                              FORMAT(GLEntry."VAT Amount", 0, '<Sign><Integer><Decimals,21><Comma,.>') + FORMAT(SemiKolon) +
                              FORMAT(GLEntry."Global Dimension 1 Code") + FORMAT(SemiKolon) +
                              FORMAT(GLEntry."Reason Code") + FORMAT(SemiKolon) +
                              FORMAT(GLEntry."Entry No.") + FORMAT(SemiKolon) +
                              FORMAT(GLEntry."User ID") + FORMAT(SemiKolon) +
                              FORMAT(GLEntry."Source Code") + FORMAT(SemiKolon) +
                              FORMAT(GLEntry."Transaction No.") + FORMAT(SemiKolon) +
                              FORMAT(GLEntry."Source No.") + FORMAT(SemiKolon) +
                              FORMAT(SourceType_txt) +
                              FORMAT(CR) + FORMAT(LF));
        until ReconGLOutboundEntry.NEXT = 0;
    end;

    procedure Open_Items(var TempBlob: Codeunit "Temp Blob"; "p_Extraction Type": Option BlackLine_NF_BlackLine_Account_Items,BlackLine_Bank,BlackLine_Customer,BlackLine_GL_Account_Balance,BlackLine_Vendor,BlackLine_IC_ACC,BlackLine_IC_BAL,BlackLine_IC_FIN,BlackLine_IC_FV,BlackLine_IC_INT,BlackLine_IC_PnL,BlackLine_Match; p_Batch_Guid: GUID)
    var
        ReconGLOutboundEntry: Record "Recon. G/L Outbound Entry";
    begin
        Init_Execution();

        TempBlob.CREATEOUTSTREAM(OStream, TEXTENCODING::UTF8);

        ReconGLOutboundEntry.SETCURRENTKEY(Batch_Guid, CompanyID, "G/L Account No.", "G/L Entry No.");
        ReconGLOutboundEntry.SETRANGE("Extraction Type", "p_Extraction Type");
        ReconGLOutboundEntry.SETRANGE(Batch_Guid, p_Batch_Guid);
        if NOT ReconGLOutboundEntry.FINDSET then
            EXIT;

        repeat
            OStream.WRITETEXT(FORMAT(ReconGLOutboundEntry.CompanyID) + FORMAT(TAB) +
                              FORMAT(ReconGLOutboundEntry."G/L Account No.") + FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(ReconGLOutboundEntry.CompanyID + '-' + ReconGLOutboundEntry."G/L Account No." + '-' + FORMAT(CALCDATE('-CM-1M', WORKDATE), 0, '<Year4><Month,2>') + '-' + FORMAT(ReconGLOutboundEntry."G/L Entry No.")) + FORMAT(TAB) +
                              FORMAT(ReconGLOutboundEntry."Posting Date", 0, '<Year4>-<Month,2>-<day,2>') + FORMAT(TAB) +
                              FORMAT(ReconGLOutboundEntry."Open Date", 0, '<Year4>-<Month,2>-<day,2>') + FORMAT(TAB) + //Open date / First day last month
                              FORMAT(WORKDATE, 0, '<Year4>-<Month,2>-01') + FORMAT(TAB) + //Close date / First day this month
                              FORMAT('General') + FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT('L') + FORMAT(TAB) +
                              FORMAT('G') + FORMAT(TAB) +
                              FORMAT('TRUE') + FORMAT(TAB) +
                              FORMAT(ReconGLOutboundEntry.Description) + FORMAT(TAB) +
                              FORMAT(ReconGLOutboundEntry."Document No.") + FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(ReconGLOutboundEntry."External Document No.") + FORMAT(TAB) +
                              FORMAT(ReconGLOutboundEntry."Global Dimension 1 Code") + FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(ReconGLOutboundEntry."Remaining Amount", 0, '<Sign><Integer><Decimals,21><Comma,.>') + FORMAT(TAB) +
                              FORMAT(ReconGLOutboundEntry."Currency Code") +
                              FORMAT(CR) + FORMAT(LF));
        until ReconGLOutboundEntry.NEXT = 0;
    end;

    procedure Master_Data_Account(var TempBlob: Codeunit "Temp Blob"; "p_Extraction Type": Option BlackLine_NF_BlackLine_Account_Items,BlackLine_Bank,BlackLine_Customer,BlackLine_GL_Account_Balance,BlackLine_Vendor,BlackLine_IC_ACC,BlackLine_IC_BAL,BlackLine_IC_FIN,BlackLine_IC_FV,BlackLine_IC_INT,BlackLine_IC_PnL,BlackLine_Match; p_Batch_Guid: GUID)
    var
        ReconMasterOutbEntry: Record "Recon Master Outb. Entry";
    begin
        Init_Execution();
        TempBlob.CREATEOUTSTREAM(OStream, TEXTENCODING::UTF8);

        ReconMasterOutbEntry.SETCURRENTKEY("Extraction Type", CompanyID, "No.");
        ReconMasterOutbEntry.SETRANGE("Extraction Type", "p_Extraction Type");
        ReconMasterOutbEntry.SETRANGE(Batch_Guid, p_Batch_Guid);
        if NOT ReconMasterOutbEntry.FINDSET then
            EXIT;

        repeat
            OStream.WRITETEXT(FORMAT(ReconMasterOutbEntry.CompanyID) + FORMAT(TAB) +
                              FORMAT(ReconMasterOutbEntry."No.") + FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(ReconMasterOutbEntry.Name) + FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT('A') + FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(ReconMasterOutbEntry."Active Account") + FORMAT(TAB) +
                              FORMAT(ReconMasterOutbEntry."Any Activity in period") + FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(ReconMasterOutbEntry.Currency) + FORMAT(TAB) +
                              FORMAT(ReconMasterOutbEntry."Last Date of the period", 0, '<Month,2>-<Day,2>-<Year4>') + FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(ReconMasterOutbEntry.Balance, 0, '<Precision,2:2><Standard Format,2>') + FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(CR) + FORMAT(LF));
        until ReconMasterOutbEntry.NEXT = 0;
    end;

    procedure Master_Data_Bank(var TempBlob: Codeunit "Temp Blob"; "p_Extraction Type": Option BlackLine_NF_BlackLine_Account_Items,BlackLine_Bank,BlackLine_Customer,BlackLine_GL_Account_Balance,BlackLine_Vendor,BlackLine_IC_ACC,BlackLine_IC_BAL,BlackLine_IC_FIN,BlackLine_IC_FV,BlackLine_IC_INT,BlackLine_IC_PnL,BlackLine_Match; p_Batch_Guid: GUID)
    var
        ReconMasterOutbEntry: Record "Recon Master Outb. Entry";
    begin
        Init_Execution();
        TempBlob.CREATEOUTSTREAM(OStream, TEXTENCODING::UTF8);

        ReconMasterOutbEntry.SETCURRENTKEY("Extraction Type", CompanyID, "No.");
        ReconMasterOutbEntry.SETRANGE("Extraction Type", "p_Extraction Type");
        ReconMasterOutbEntry.SETRANGE(Batch_Guid, p_Batch_Guid);
        if NOT ReconMasterOutbEntry.FINDSET then
            EXIT;

        repeat
            OStream.WRITETEXT(FORMAT(ReconMasterOutbEntry.CompanyID) + FORMAT(TAB) +
                              FORMAT(ReconMasterOutbEntry."G/L Account") + FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(ReconMasterOutbEntry."No." + ' - ' + ReconMasterOutbEntry.Name) + FORMAT(TAB) +
                              FORMAT('Balance_Bank') + FORMAT(TAB) +
                              FORMAT(ReconMasterOutbEntry."Last Date of the period", 0, '<Month,2>-<Day,2>-<Year4>') + FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(ReconMasterOutbEntry."Balance (LCY)", 0, '<Precision,2:2><Standard Format,2>') + FORMAT(TAB) +
                              FORMAT(ReconMasterOutbEntry.Balance, 0, '<Precision,2:2><Standard Format,2>') + FORMAT(TAB) +
                              FORMAT(ReconMasterOutbEntry.Currency) +
                              FORMAT(CR) + FORMAT(LF));
        until ReconMasterOutbEntry.NEXT = 0;
    end;

    procedure Master_Data_Customer(var TempBlob: Codeunit "Temp Blob"; "p_Extraction Type": Option BlackLine_NF_BlackLine_Account_Items,BlackLine_Bank,BlackLine_Customer,BlackLine_GL_Account_Balance,BlackLine_Vendor,BlackLine_IC_ACC,BlackLine_IC_BAL,BlackLine_IC_FIN,BlackLine_IC_FV,BlackLine_IC_INT,BlackLine_IC_PnL,BlackLine_Match; p_Batch_Guid: GUID)
    var
        ReconMasterOutbEntry: Record "Recon Master Outb. Entry";
    begin
        Init_Execution();
        TempBlob.CREATEOUTSTREAM(OStream, TEXTENCODING::UTF8);

        ReconMasterOutbEntry.SETCURRENTKEY("Extraction Type", CompanyID, "No.");
        ReconMasterOutbEntry.SETRANGE("Extraction Type", "p_Extraction Type");
        ReconMasterOutbEntry.SETRANGE(Batch_Guid, p_Batch_Guid);
        if NOT ReconMasterOutbEntry.FINDSET then
            EXIT;

        repeat
            OStream.WRITETEXT(FORMAT(ReconMasterOutbEntry.CompanyID) + FORMAT(TAB) +
                              FORMAT(ReconMasterOutbEntry."G/L Account") + FORMAT(TAB) +
                              FORMAT(TAB) +
                              //FORMAT(Name)+FORMAT(TAB)+
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(ReconMasterOutbEntry."No." + ' - ' + ReconMasterOutbEntry.Name) + FORMAT(TAB) +
                              FORMAT('Balance_Subledger') + FORMAT(TAB) +
                              FORMAT(ReconMasterOutbEntry."Last Date of the period", 0, '<Month,2>-<Day,2>-<Year4>') + FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(ReconMasterOutbEntry."Balance (LCY)", 0, '<Precision,2:2><Standard Format,2>') + FORMAT(TAB) +
                              FORMAT(ReconMasterOutbEntry.Currency) +
                              FORMAT(CR) + FORMAT(LF));
        until ReconMasterOutbEntry.NEXT = 0;
    end;

    procedure Master_Data_Vendor(var TempBlob: Codeunit "Temp Blob"; "p_Extraction Type": Option BlackLine_NF_BlackLine_Account_Items,BlackLine_Bank,BlackLine_Customer,BlackLine_GL_Account_Balance,BlackLine_Vendor,BlackLine_IC_ACC,BlackLine_IC_BAL,BlackLine_IC_FIN,BlackLine_IC_FV,BlackLine_IC_INT,BlackLine_IC_PnL,BlackLine_Match; p_Batch_Guid: GUID)
    var
        ReconMasterOutbEntry: Record "Recon Master Outb. Entry";
    begin
        Init_Execution();
        TempBlob.CREATEOUTSTREAM(OStream, TEXTENCODING::UTF8);

        ReconMasterOutbEntry.SETCURRENTKEY("Extraction Type", CompanyID, "No.");
        ReconMasterOutbEntry.SETRANGE("Extraction Type", "p_Extraction Type");
        ReconMasterOutbEntry.SETRANGE(Batch_Guid, p_Batch_Guid);
        if NOT ReconMasterOutbEntry.FINDSET then
            EXIT;

        repeat
            OStream.WRITETEXT(FORMAT(ReconMasterOutbEntry.CompanyID) + FORMAT(TAB) +
                              FORMAT(ReconMasterOutbEntry."G/L Account") + FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(ReconMasterOutbEntry."No." + ' - ' + ReconMasterOutbEntry.Name) + FORMAT(TAB) +
                              FORMAT('Balance_Subledger') + FORMAT(TAB) +
                              FORMAT(ReconMasterOutbEntry."Last Date of the period", 0, '<Month,2>-<Day,2>-<Year4>') + FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(TAB) +
                              FORMAT(ReconMasterOutbEntry."Balance (LCY)", 0, '<Precision,2:2><Standard Format,2>') + FORMAT(TAB) +
                              FORMAT(ReconMasterOutbEntry.Currency) +
                              FORMAT(CR) + FORMAT(LF));
        until ReconMasterOutbEntry.NEXT = 0;
    end;

    procedure IC_Data(var TempBlob: Codeunit "Temp Blob"; "p_Extraction Type": Option BlackLine_NF_BlackLine_Account_Items,BlackLine_Bank,BlackLine_Customer,BlackLine_GL_Account_Balance,BlackLine_Vendor,BlackLine_IC_ACC,BlackLine_IC_BAL,BlackLine_IC_FIN,BlackLine_IC_FV,BlackLine_IC_INT,BlackLine_IC_PnL,BlackLine_Match; p_Batch_Guid: GUID)
    var
        ReconGLOutboundEntry: Record "Recon. G/L Outbound Entry";
        CurrencyCode_Txt: Text[10];
        GeneralLedgerSetup: Record 98;
        FileType: Text[3];
    begin
        Init_Execution();

        TempBlob.CREATEOUTSTREAM(OStream, TEXTENCODING::UTF8);

        ReconGLOutboundEntry.SETCURRENTKEY(Batch_Guid, CompanyID, "G/L Account No.", "G/L Entry No.");
        ReconGLOutboundEntry.SETRANGE(Batch_Guid, p_Batch_Guid);
        ReconGLOutboundEntry.SETRANGE("Extraction Type", "p_Extraction Type");

        if NOT ReconGLOutboundEntry.FINDSET then
            EXIT;

        FileType := COPYSTR(FORMAT("p_Extraction Type"), STRLEN(FORMAT("p_Extraction Type")) - 2, 3);
        if FileType = '_FV' then
            FileType := COPYSTR(FileType, 2, 2);

        repeat
            OStream.WRITETEXT(FORMAT(COPYSTR(ReconGLOutboundEntry.CompanyID, 4, 3)) + FORMAT(TAB) +
                              FORMAT(FileType) + FORMAT(TAB) +
                              FORMAT(ReconGLOutboundEntry."G/L Account No.") + FORMAT(TAB) +
                              FORMAT(ReconGLOutboundEntry."Creation Date", 0, '<day,2>-<Month,2>-<Year4>') + ' 00:00:00' + FORMAT(TAB) +
                              FORMAT(ReconGLOutboundEntry."Posting Date", 0, '<day,2>-<Month,2>-<Year4>') + ' 00:00:00' + FORMAT(TAB) +
                              FORMAT(ReconGLOutboundEntry."Document Date", 0, '<day,2>-<Month,2>-<Year4>') + ' 00:00:00' + FORMAT(TAB) +
                              FORMAT(ReconGLOutboundEntry."Document Type") + FORMAT(TAB) +
                              FORMAT(ReconGLOutboundEntry."Document No.") + FORMAT(TAB) +
                              FORMAT(ReconGLOutboundEntry."External Document No.") + FORMAT(TAB) +
                              FORMAT(ReconGLOutboundEntry."Source Type") + FORMAT(TAB) +
                              FORMAT(ReconGLOutboundEntry."Source No.") + FORMAT(TAB) +
                              FORMAT(ReconGLOutboundEntry.Description) + FORMAT(TAB) +
                              FORMAT(ReconGLOutboundEntry."Foreign Currency Code") + FORMAT(TAB) +
                              FORMAT(ReconGLOutboundEntry."Currency Amount", 0, '<Precision,2:2><Sign><Integer><Decimals><Comma,.>') + FORMAT(TAB) +
                              FORMAT(ReconGLOutboundEntry."Currency Code") + FORMAT(TAB) +
                              FORMAT(ReconGLOutboundEntry.Amount, 0, '<Precision,2:2><Sign><Integer><Decimals><Comma,.>') + FORMAT(TAB) +
                              FORMAT(ReconGLOutboundEntry."Remaining Amount", 0, '<Precision,2:2><Sign><Integer><Decimals><Comma,.>') + FORMAT(TAB) +
                              FORMAT(ReconGLOutboundEntry."IC Partner Code") + FORMAT(TAB) +
                              FORMAT(ReconGLOutboundEntry.Closed) + FORMAT(TAB) +
                              FORMAT(TAB) + //Closed Date
                              FORMAT(COPYSTR(ReconGLOutboundEntry.CompanyID, 4, 3) + '-' + FORMAT(FileType) + '-' + FORMAT(ReconGLOutboundEntry."G/L Entry No.")) +
                              FORMAT(CR) + FORMAT(LF));
        until ReconGLOutboundEntry.NEXT = 0;
    end;
}
