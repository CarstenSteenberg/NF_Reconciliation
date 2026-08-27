report 50500 "Reconciliation Generate Data"
{
    ApplicationArea = Basic, Suite;
    Caption = 'Reconciliation Generate Data';
    UsageCategory = Tasks;
    ProcessingOnly = true;

    dataset
    {
        dataitem(Integer; Integer)
        {
            DataItemTableView = sorting(Number) where(Number = const(1));

            trigger OnAfterGetRecord()
            var
                NordiskFilmSetup: Record "Nordisk Film Setup";
            begin
                if not NordiskFilmSetup.Get() then
                    exit;

                Clear(BlankGuid);
                BatchGuid := CreateGuid();

                Clear(EnvironmentSetup);
                EnvironmentSetup.SetRange(Environment, EnvironmentSetup.GetCurrentEnvironmentName());
                EnvironmentSetup.SetRange(ReconciliationCompany, true);

                // TEST
                // CompanyId.SetRange(Company_Name, 'DK-NOH');

                if not EnvironmentSetup.FindSet() then
                    exit;

                if GuiAllowed() then
                    Window.Open(BatchInfoLbl);

                if GuiAllowed() then
                    FillOutParmBufferManual()
                else
                    FillOutParmBufferBatch();

                CleanUpMasterData();
                CleanUpOldTransData();

                // Parameter buffer must be available to StartSession in each company.
                Commit();

                repeat
                    if GuiAllowed() then begin
                        Window.Update(1, EnvironmentSetup.Company);
                        Window.Update(2, 'Generating data');
                    end;

                    GenerateDataPerCompany(EnvironmentSetup.Company);
                until EnvironmentSetup.Next() = 0;

                GenerateDataOutboundFiles();

                if GuiAllowed() then
                    Window.Close();

                ReconciliationParmBuffer.SetRange(GUID, BatchGuid);
                ReconciliationParmBuffer.DeleteAll();
            end;
        }
    }

    requestpage
    {
        layout
        {
            area(Content)
            {
                group(Options)
                {
                    Caption = 'Options';

                    field(OpenItems; OpenItemsRP)
                    {
                        ApplicationArea = Basic, Suite;
                        Caption = 'Open Items';
                    }

                    group(MasterData)
                    {
                        Caption = 'Master data';

                        field(Customer; CustomerRP)
                        {
                            ApplicationArea = All;
                            Caption = 'Customer';
                        }
                        field(Vendor; VendorRP)
                        {
                            ApplicationArea = All;
                            Caption = 'Vendor';
                        }
                        field(BankAccount; BankAccRP)
                        {
                            ApplicationArea = All;
                            Caption = 'Bank Account';
                        }
                        field(GLAccount; GLAccRP)
                        {
                            ApplicationArea = All;
                            Caption = 'G/L Account';
                        }
                        field(ICACC; ICACCRP)
                        {
                            ApplicationArea = All;
                            Caption = 'IC_ACC';
                        }
                        field(ICBAL; ICBALRP)
                        {
                            ApplicationArea = All;
                            Caption = 'IC_BAL';
                        }
                        field(ICFIN; ICFINRP)
                        {
                            ApplicationArea = All;
                            Caption = 'IC_FIN';
                        }
                        field(ICFV; ICFVRP)
                        {
                            ApplicationArea = All;
                            Caption = 'IC_FV';
                        }
                        field(ICINT; ICINTRP)
                        {
                            ApplicationArea = All;
                            Caption = 'IC_INT';
                        }
                        field(ICPnL; ICPnLRP)
                        {
                            ApplicationArea = All;
                            Caption = 'IC_Pnl';
                        }
                    }

                    field(GenerateFiles; GenerateFilesRP)
                    {
                        ApplicationArea = All;
                        Caption = 'Generate files';
                        Visible = false;
                    }
                }
            }
        }
    }

    trigger OnInitReport()
    begin

        if not EnvironmentSetup.IsCurrentCompanyCommon() then
            Error(JobMustRunInCommonErr);
    end;

    local procedure GenerateDataPerCompany(CompanyName: Text[30])
    var
        SessionId: Integer;
    begin
        if not StartSession(
            SessionId,
            Codeunit::"Reconciliation Generate Data",
            CompanyName,
            ReconciliationParmBuffer)
        then
            Error(JobDidNotExecuteErr, CompanyName);

        while true do begin
            Sleep(1000);
            if not IsSessionActive(SessionId) then
                exit;
        end;
    end;

    local procedure FillOutParmBufferManual()
    begin
        case OpenItemsRP of
            OpenItemsRP::Ignore:
                ;
            OpenItemsRP::Full:
                FillOutParmBuffer('OI-FULL');
            OpenItemsRP::Incremental:
                FillOutParmBuffer('OI-INCR');
        end;

        case CustomerRP of
            CustomerRP::Ignore:
                ;
            CustomerRP::Full:
                FillOutParmBuffer('MASTER-CUSTOMER-FULL');
            CustomerRP::Incremental:
                FillOutParmBuffer('MASTER-CUSTOMER-INCR');
        end;

        case VendorRP of
            VendorRP::Ignore:
                ;
            VendorRP::Full:
                FillOutParmBuffer('MASTER-VENDOR-FULL');
            VendorRP::Incremental:
                FillOutParmBuffer('MASTER-VENDOR-INCR');
        end;

        if BankAccRP then
            FillOutParmBuffer('MASTER-BANKACC-FULL');
        if GLAccRP then
            FillOutParmBuffer('MASTER-GLACC-FULL');
        if ICACCRP then
            FillOutParmBuffer('IC-ACC');
        if ICBALRP then
            FillOutParmBuffer('IC-BAL');
        if ICFINRP then
            FillOutParmBuffer('IC-FIN');
        if ICFVRP then
            FillOutParmBuffer('IC-FV');
        if ICINTRP then
            FillOutParmBuffer('IC-INT');
        if ICPnLRP then
            FillOutParmBuffer('IC-PNL');
    end;

    local procedure FillOutParmBufferBatch()
    begin
        if CheckIfExecutedToday('ITEMF') then
            FillOutParmBuffer('OI-FULL');
        if CheckIfExecutedToday('ITEMI') then
            FillOutParmBuffer('OI-INCR');

        if CheckIfExecutedToday('CUSTF') then
            FillOutParmBuffer('MASTER-CUSTOMER-FULL');
        if CheckIfExecutedToday('CUSTI') then
            FillOutParmBuffer('MASTER-CUSTOMER-INCR');

        if CheckIfExecutedToday('VENDF') then
            FillOutParmBuffer('MASTER-VENDOR-FULL');
        if CheckIfExecutedToday('VENDI') then
            FillOutParmBuffer('MASTER-VENDOR-INCR');

        if CheckIfExecutedToday('GLF') then
            FillOutParmBuffer('MASTER-GLACC-FULL');

        if CheckIfExecutedToday('BANKF') then
            FillOutParmBuffer('MASTER-BANKACC-FULL');

        if ICACCRP then
            FillOutParmBuffer('IC-ACC');
        if ICBALRP then
            FillOutParmBuffer('IC-BAL');
        if ICFINRP then
            FillOutParmBuffer('IC-FIN');
        if ICFVRP then
            FillOutParmBuffer('IC-FV');
        if ICINTRP then
            FillOutParmBuffer('IC-INT');
        if ICPnLRP then
            FillOutParmBuffer('IC-PNL');
    end;

    local procedure FillOutParmBuffer(BatchName: Text)
    var
        EntryNo: Integer;
    begin
        EntryNo := 1;
        ReconciliationParmBuffer.SetRange(GUID, BatchGuid);
        if ReconciliationParmBuffer.FindLast() then
            EntryNo := ReconciliationParmBuffer."Entry No." + 1;

        Clear(ReconciliationParmBuffer);
        ReconciliationParmBuffer.Init();
        ReconciliationParmBuffer.GUID := BatchGuid;
        ReconciliationParmBuffer."Entry No." := EntryNo;

        case true of
            StrPos(BatchName, 'OI') <> 0:
                ReconciliationParmBuffer."Extraction Type" :=
                    ReconciliationParmBuffer."Extraction Type"::BlackLine_NF_BlackLine_Account_Items;
            StrPos(BatchName, 'MASTER-BANK') <> 0:
                ReconciliationParmBuffer."Extraction Type" :=
                    ReconciliationParmBuffer."Extraction Type"::BlackLine_Bank;
            StrPos(BatchName, 'MASTER-CUSTOMER') <> 0:
                ReconciliationParmBuffer."Extraction Type" :=
                    ReconciliationParmBuffer."Extraction Type"::BlackLine_Customer;
            StrPos(BatchName, 'MASTER-VENDOR') <> 0:
                ReconciliationParmBuffer."Extraction Type" :=
                    ReconciliationParmBuffer."Extraction Type"::BlackLine_Vendor;
            StrPos(BatchName, 'MASTER-GLACC') <> 0:
                ReconciliationParmBuffer."Extraction Type" :=
                    ReconciliationParmBuffer."Extraction Type"::BlackLine_GL_Account_Balance;
            StrPos(BatchName, 'IC-ACC') <> 0:
                ReconciliationParmBuffer."Extraction Type" :=
                    ReconciliationParmBuffer."Extraction Type"::BlackLine_IC_ACC;
            StrPos(BatchName, 'IC-BAL') <> 0:
                ReconciliationParmBuffer."Extraction Type" :=
                    ReconciliationParmBuffer."Extraction Type"::BlackLine_IC_BAL;
            StrPos(BatchName, 'IC-FIN') <> 0:
                ReconciliationParmBuffer."Extraction Type" :=
                    ReconciliationParmBuffer."Extraction Type"::BlackLine_IC_FIN;
            StrPos(BatchName, 'IC-FV') <> 0:
                ReconciliationParmBuffer."Extraction Type" :=
                    ReconciliationParmBuffer."Extraction Type"::BlackLine_IC_FV;
            StrPos(BatchName, 'IC-INT') <> 0:
                ReconciliationParmBuffer."Extraction Type" :=
                    ReconciliationParmBuffer."Extraction Type"::BlackLine_IC_INT;
            StrPos(BatchName, 'IC-PNL') <> 0:
                ReconciliationParmBuffer."Extraction Type" :=
                    ReconciliationParmBuffer."Extraction Type"::BlackLine_IC_PnL;
        end;

        if StrPos(BatchName, 'FULL') <> 0 then
            ReconciliationParmBuffer."Execution Mode" :=
                ReconciliationParmBuffer."Execution Mode"::Full
        else
            ReconciliationParmBuffer."Execution Mode" :=
                ReconciliationParmBuffer."Execution Mode"::Incremental;

        ReconciliationParmBuffer."Generate Output" := true;
        ReconciliationParmBuffer.Insert();
    end;

    local procedure GenerateDataOutboundFiles()
    var
        LocalReconciliationParmBuffer: Record "Reconciliation Parm Buffer";
    begin
        Clear(LocalReconciliationParmBuffer);
        LocalReconciliationParmBuffer.SetRange(GUID, BatchGuid);
        LocalReconciliationParmBuffer.SetRange("Generate Output", true);
        if not LocalReconciliationParmBuffer.FindSet() then
            exit;

        if GuiAllowed() then
            Window.Update(1, '');

        repeat
            GenerateDataOutboundOneFile(LocalReconciliationParmBuffer);
            if GuiAllowed() then
                Window.Update(2, 'Generating file Output');
        until LocalReconciliationParmBuffer.Next() = 0;
    end;

    local procedure GenerateDataOutboundOneFile(LocalReconciliationParmBuffer: Record "Reconciliation Parm Buffer")
    var
        OutboundData: Record Outbound_Data;
        TempBlob: Codeunit "Temp Blob";
        TempInStream: InStream;
        BlobOutStream: OutStream;
        BlackLineFileCreation: Codeunit "BlackLine File Creation";
        IntegrationService: Codeunit Integration_Service;
        EnvironmentInformation: Codeunit "Environment Information";
    begin
        Clear(TempBlob);
        OutboundData.Init();
        OutboundData.MessageId := CreateGuid();
        OutboundData.MessageType := Format(LocalReconciliationParmBuffer."Extraction Type");
        OutboundData.MessageType += '_' + CopyStr(EnvironmentInformation.GetEnvironmentName(), StrLen(EnvironmentInformation.GetEnvironmentName()) - 1, 2);
        OutboundData."Data Source Type" := 'BlackLine';
        OutboundData."Data Source Code" := OutboundData.MessageType;

        OutboundData.Company := CompanyName();
        OutboundData.Insert_DateTime := CurrentDateTime();
        OutboundData.FileType := OutboundData.FileType::txt;

        case LocalReconciliationParmBuffer."Extraction Type" of
            LocalReconciliationParmBuffer."Extraction Type"::BlackLine_NF_BlackLine_Account_Items:
                BlackLineFileCreation.Open_Items(
                    TempBlob,
                    LocalReconciliationParmBuffer."Extraction Type",
                    LocalReconciliationParmBuffer.GUID);
            LocalReconciliationParmBuffer."Extraction Type"::BlackLine_Bank:
                BlackLineFileCreation.Master_Data_Bank(
                    TempBlob,
                    LocalReconciliationParmBuffer."Extraction Type",
                    LocalReconciliationParmBuffer.GUID);
            LocalReconciliationParmBuffer."Extraction Type"::BlackLine_Customer:
                BlackLineFileCreation.Master_Data_Customer(
                    TempBlob,
                    LocalReconciliationParmBuffer."Extraction Type",
                    LocalReconciliationParmBuffer.GUID);
            LocalReconciliationParmBuffer."Extraction Type"::BlackLine_GL_Account_Balance:
                BlackLineFileCreation.Master_Data_Account(
                    TempBlob,
                    LocalReconciliationParmBuffer."Extraction Type",
                    LocalReconciliationParmBuffer.GUID);
            LocalReconciliationParmBuffer."Extraction Type"::BlackLine_Vendor:
                BlackLineFileCreation.Master_Data_Vendor(
                    TempBlob,
                    LocalReconciliationParmBuffer."Extraction Type",
                    LocalReconciliationParmBuffer.GUID);
            LocalReconciliationParmBuffer."Extraction Type"::BlackLine_IC_ACC,
            LocalReconciliationParmBuffer."Extraction Type"::BlackLine_IC_BAL,
            LocalReconciliationParmBuffer."Extraction Type"::BlackLine_IC_FIN,
            LocalReconciliationParmBuffer."Extraction Type"::BlackLine_IC_FV,
            LocalReconciliationParmBuffer."Extraction Type"::BlackLine_IC_INT,
            LocalReconciliationParmBuffer."Extraction Type"::BlackLine_IC_PnL:
                BlackLineFileCreation.IC_Data(
                    TempBlob,
                    LocalReconciliationParmBuffer."Extraction Type",
                    LocalReconciliationParmBuffer.GUID);
        end;
        if not TempBlob.HasValue() then
            exit;

        TempBlob.CreateInStream(TempInStream, TextEncoding::UTF8);

        OutboundData.Document.CreateOutStream(BlobOutStream);
        CopyStream(BlobOutStream, TempInStream);

        OutboundData.Insert();

        IntegrationService.AddStatusLog(OutboundData.MessageId, enum::"Status Log Type"::Outbound, OutboundData.MessageType, 1);
    end;

    local procedure CheckIfExecutedToday(BatchName: Text): Boolean
    var
        NordiskFilmSetup: Record "Nordisk Film Setup";
        Description: Text[50];
    begin
        if BatchName = '' then
            exit(false);

        if not NordiskFilmSetup.Get() then
            exit(false);

        ReconciliationGenerateData.CheckDateStatus(NordiskFilmSetup."Reconciliation Calendar", WorkDate(), Description);

        exit(StrPos(UpperCase(Description), UpperCase(BatchName)) <> 0);
    end;

    local procedure CleanUpMasterData()
    var
        BTReconMasterOutbEntry: Record "Recon Master Outb. Entry";
        LastBatchGuid: Guid;
    begin
        if GuiAllowed() then
            Window.Update(2, 'Clean up master data');

        BTReconMasterOutbEntry.SetCurrentKey("Export Date/Time", Type);
        BTReconMasterOutbEntry.SetFilter(Type, '%1|%2', BTReconMasterOutbEntry.Type::Bank, BTReconMasterOutbEntry.Type::"G/L Account");
        BTReconMasterOutbEntry.DeleteAll();

        // <NF> #6231548 Blackline IC Partner files from NAV
        ReconciliationParmBuffer.SetRange(GUID, BatchGuid);
        ReconciliationParmBuffer.SetRange("Extraction Type", ReconciliationParmBuffer."Extraction Type"::BlackLine_Customer);
        if ReconciliationParmBuffer.FindFirst() then
            case ReconciliationParmBuffer."Execution Mode" of
                ReconciliationParmBuffer."Execution Mode"::Full:
                    begin
                        BTReconMasterOutbEntry.SetRange(Type, BTReconMasterOutbEntry.Type::Customer);
                        BTReconMasterOutbEntry.DeleteAll();
                    end;
                ReconciliationParmBuffer."Execution Mode"::Incremental:
                    begin
                        BTReconMasterOutbEntry.SetRange(Type, BTReconMasterOutbEntry.Type::Customer);
                        BTReconMasterOutbEntry.SetRange("Execution Mode", BTReconMasterOutbEntry."Execution Mode"::Incremental);
                        if BTReconMasterOutbEntry.FindLast() then begin
                            LastBatchGuid := BTReconMasterOutbEntry.Batch_Guid;
                            BTReconMasterOutbEntry.SetFilter(Batch_Guid, '<>%1', LastBatchGuid);
                            BTReconMasterOutbEntry.DeleteAll();
                        end;

                        BTReconMasterOutbEntry.SetRange(Type, BTReconMasterOutbEntry.Type::Customer);
                        BTReconMasterOutbEntry.SetRange("Execution Mode", BTReconMasterOutbEntry."Execution Mode"::Full);
                        if BTReconMasterOutbEntry.FindLast() then begin
                            LastBatchGuid := BTReconMasterOutbEntry.Batch_Guid;
                            BTReconMasterOutbEntry.SetFilter(Batch_Guid, '<>%1', LastBatchGuid);
                            BTReconMasterOutbEntry.DeleteAll();
                        end;
                    end;
            end;

        ReconciliationParmBuffer.SetRange(GUID, BatchGuid);
        ReconciliationParmBuffer.SetRange("Extraction Type", ReconciliationParmBuffer."Extraction Type"::BlackLine_Vendor);
        if ReconciliationParmBuffer.FindFirst() then
            case ReconciliationParmBuffer."Execution Mode" of
                ReconciliationParmBuffer."Execution Mode"::Full:
                    begin
                        BTReconMasterOutbEntry.SetRange(Type, BTReconMasterOutbEntry.Type::Vendor);
                        BTReconMasterOutbEntry.DeleteAll();
                    end;
                ReconciliationParmBuffer."Execution Mode"::Incremental:
                    begin
                        BTReconMasterOutbEntry.SetRange(Type, BTReconMasterOutbEntry.Type::Vendor);
                        BTReconMasterOutbEntry.SetRange(
                            "Execution Mode",
                            BTReconMasterOutbEntry."Execution Mode"::Incremental);
                        if BTReconMasterOutbEntry.FindLast() then begin
                            LastBatchGuid := BTReconMasterOutbEntry.Batch_Guid;
                            BTReconMasterOutbEntry.SetFilter(Batch_Guid, '<>%1', LastBatchGuid);
                            BTReconMasterOutbEntry.DeleteAll();
                        end;

                        BTReconMasterOutbEntry.SetRange(Type, BTReconMasterOutbEntry.Type::Vendor);
                        BTReconMasterOutbEntry.SetRange("Execution Mode", BTReconMasterOutbEntry."Execution Mode"::Full);
                        if BTReconMasterOutbEntry.FindLast() then begin
                            LastBatchGuid := BTReconMasterOutbEntry.Batch_Guid;
                            BTReconMasterOutbEntry.SetFilter(Batch_Guid, '<>%1', LastBatchGuid);
                            BTReconMasterOutbEntry.DeleteAll();
                        end;
                    end;
            end;
        // </NF> #6231548 Blackline IC Partner files from NAV
    end;

    local procedure CleanUpOldTransData()
    var
        BTReconGLOutboundEntry: Record "Recon. G/L Outbound Entry";
    begin
        if GuiAllowed() then
            Window.Update(2, 'Clean up old transaction data');

        Clear(BTReconGLOutboundEntry);
        BTReconGLOutboundEntry.SetCurrentKey("Extraction Type", "Execution Mode");
        BTReconGLOutboundEntry.SetRange("Extraction Type", BTReconGLOutboundEntry."Extraction Type"::BlackLine_IC_ACC,
            BTReconGLOutboundEntry."Extraction Type"::BlackLine_IC_PnL);
        BTReconGLOutboundEntry.DeleteAll();

        ReconciliationParmBuffer.SetRange(GUID, BatchGuid);
        ReconciliationParmBuffer.SetRange("Extraction Type", ReconciliationParmBuffer."Extraction Type"::BlackLine_NF_BlackLine_Account_Items);
        ReconciliationParmBuffer.SetRange("Execution Mode", ReconciliationParmBuffer."Execution Mode"::Full);

        // For a full load, delete all old data.
        if not ReconciliationParmBuffer.IsEmpty() then begin
            BTReconGLOutboundEntry.SetRange("Extraction Type", ReconciliationParmBuffer."Extraction Type"::BlackLine_NF_BlackLine_Account_Items);
            BTReconGLOutboundEntry.DeleteAll();
        end;

        Sleep(15000);

    end;

    var
        EnvironmentSetup: Record "Environment Setup";
        ReconciliationGenerateData: Codeunit "Reconciliation Generate Data";
        ReconciliationParmBuffer: Record "Reconciliation Parm Buffer";
        OpenItemsRP: Option Ignore,Incremental,Full;
        CustomerRP: Option Ignore,Incremental,Full;
        VendorRP: Option Ignore,Incremental,Full;
        BankAccRP: Boolean;
        GLAccRP: Boolean;
        ICACCRP: Boolean;
        ICBALRP: Boolean;
        ICFINRP: Boolean;
        ICFVRP: Boolean;
        ICINTRP: Boolean;
        ICPnLRP: Boolean;
        GenerateFilesRP: Boolean;
        BlankGuid: Guid;
        BatchGuid: Guid;
        Window: Dialog;
        JobMustRunInCommonErr: Label 'This job must be executed in COMMON';
        JobDidNotExecuteErr: Label 'The job did not execute in %1', Comment = '%1 = company name';
        BatchInfoLbl: Label 'Company.: #######1##########\Process.: ##########2##########';
}
