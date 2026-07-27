table 50502 "Recon. G/L Outbound Entry"
{
    DataPerCompany = false;
    Caption = 'Reconciliation G/L Outbound Entry';

    fields
    {
        field(1; "Entry No."; Integer) { }
        field(10; "G/L Account No."; Code[20]) { TableRelation = "G/L Account"; }
        field(11; "Posting Date"; Date) { ClosingDates = true; }
        field(12; Description; Text[50]) { }
        field(13; Amount; Decimal) { AutoFormatType = 1; }
        field(14; "IC Partner Code"; Code[20]) { TableRelation = "IC Partner"; }
        field(15; "Remaining Amount"; Decimal) { Editable = false; }
        field(16; "G/L Entry No."; Integer) { }
        field(17; "Creation Date"; Date) { Editable = false; }
        field(18; "Document No."; Code[20]) { }
        field(19; "External Document No."; Code[35]) { }
        field(20; "Currency Code"; Code[10]) { TableRelation = Currency; }
        field(21; "Global Dimension 1 Code"; Code[20]) { TableRelation = "Dimension Value".Code where("Global Dimension No." = const(1)); CaptionClass = '1,1,1'; }
        field(22; "Open Date"; Date) { }
        field(23; "Document Date"; Date) { DataClassification = ToBeClassified; Editable = false; }
        field(24; "Source Type"; Text[30]) { DataClassification = ToBeClassified; }
        field(25; "Source No."; Code[20]) { DataClassification = ToBeClassified; }
        field(26; "Foreign Currency Code"; Code[10]) { TableRelation = Currency; DataClassification = ToBeClassified; }
        field(27; "Currency Amount"; Decimal) { Editable = false; }
        field(28; Closed; Text[5]) { DataClassification = ToBeClassified; }
        field(29; "Document Type"; Text[30]) { DataClassification = ToBeClassified; }
        field(100; "Inserted By"; Code[50]) { }
        field(101; "Inserted Date/Time"; DateTime) { }
        field(102; "Export Date/Time"; DateTime) { }
        field(103; "Error Log No."; Integer) { }
        field(104; Status; Option) { OptionMembers = Open,Error,Released,Exported; }
        field(105; Errors; Boolean) { FieldClass = FlowField; CalcFormula = exist("Error Log Entry" where("Table ID" = const(82115), "Error No." = field("Error Log No."))); Editable = false; }
        field(106; CompanyID; Code[20]) { }
        field(107; "Extraction Type"; Option) { OptionMembers = BlackLine_NF_BlackLine_Account_Items,BlackLine_Bank,BlackLine_Customer,BlackLine_GL_Account_Balance,BlackLine_Vendor,BlackLine_IC_ACC,BlackLine_IC_BAL,BlackLine_IC_FIN,BlackLine_IC_FV,BlackLine_IC_INT,BlackLine_IC_PnL,BlackLine_Match; }
        field(108; "Execution Mode"; Option) { OptionMembers = Full,Incremental; }
        field(110; Batch_Guid; Guid) { }
    }
    keys
    {
        key(PK; "Entry No.") { Clustered = true; }
        key(K1; "Export Date/Time", "Execution Mode", Batch_Guid) { }
        key(K2; Batch_Guid, CompanyID, "G/L Account No.", "G/L Entry No.", "Extraction Type", "Execution Mode") { }
        key(K3; Batch_Guid, "G/L Entry No.") { }
        key(K4; "Extraction Type", "Execution Mode", "G/L Entry No.") { }
    }
    trigger OnInsert()
    begin
        "Inserted By" := UserId();
        "Inserted Date/Time" := CurrentDateTime();
    end;
}
