table 50202 "Reconciliation Buffer"
{
    DataClassification = ToBeClassified;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
        }
        field(10; GL_Account_No; Code[20])
        {
            Caption = 'G/L Account No.';
            TableRelation = "G/L Account";
        }
        field(11; "Posting Date"; Text[20])
        {
            Caption = 'Posting Date';
        }
        field(12; Description; Text[50])
        {
            Caption = 'Description';
        }
        field(13; "Amount LCY"; Decimal)
        {
            Caption = 'Amount';
            AutoFormatType = 1;
        }
        field(14; "IC Partner Code"; Code[20])
        {
            Caption = 'IC Partner Code';
            TableRelation = "IC Partner";
        }
        field(15; "Remaining Amount"; Decimal)
        {
            Caption = 'Remaining Amount';
            Editable = false;
        }
        field(16; GL_Entry_No; Integer)
        {
            Caption = 'G/L Entry No.';
        }
        field(17; "Creation Date"; Text[20])
        {
            Caption = 'Creation Date';
            Editable = false;
        }
        field(18; "Document No."; Code[20])
        {
            Caption = 'Document No.';
        }
        field(19; "External Document No."; Code[35])
        {
            Caption = 'External Document No.';
        }
        field(20; "Currency Code"; Code[10])
        {
            Caption = 'Currency Code';
            TableRelation = Currency;
        }
        field(21; Department; Code[20])
        {
            Caption = 'Department';
        }
        field(22; "Open Date"; Text[20])
        {
            Caption = 'Open Date';
        }
        field(23; "Document Date"; Date)
        {
            Caption = 'Document Date';
            Editable = false;
        }
        field(24; "Source Type"; Text[30])
        {
            Caption = 'Source Type';
        }
        field(25; "Source No."; Code[20])
        {
            Caption = 'Source No.';
            TableRelation = if ("Source Type" = const('Customer')) Customer
            else if ("Source Type" = const('Vendor')) Vendor
            else if ("Source Type" = const('Bank Account')) "Bank Account"
            else if ("Source Type" = const('Fixed Asset')) "Fixed Asset"
            else if ("Source Type" = const('Employee')) Employee;
        }
        field(26; "Foreign Currency Code"; Code[10])
        {
            Caption = 'Foreign Currency Code';
            TableRelation = Currency;
        }
        field(27; "Currency Amount"; Decimal)
        {
            Caption = 'Currency Amount';
            Editable = false;
        }
        field(28; Closed; Text[5])
        {
            Caption = 'Closed';
        }
        field(29; "Document Type"; Text[30])
        {
            Caption = 'Document Type';
        }
        field(30; Type; Text[30])
        {
            Caption = 'Type';
        }
        field(31; "No"; Code[20])
        {
            Caption = 'No';
        }
        field(32; Blocked; Boolean)
        {
            Caption = 'Blocked';
        }
        field(100; "Inserted By"; Code[50])
        {
            Caption = 'Inserted By';
        }
        field(101; "Inserted Date/Time"; DateTime)
        {
            Caption = 'Inserted Date/Time';
        }
        field(102; "Export Date/Time"; DateTime)
        {
            Caption = 'Export Date/Time';
        }
        field(103; "Error Log No."; Integer)
        {
            Caption = 'Error Log No.';
        }
        field(104; Status; Option)
        {
            Caption = 'Status';
            OptionMembers = Open,Error,Released,Exported;
            OptionCaption = 'Open,Error,Released,Exported';
        }
        field(105; Errors; Boolean)
        {
            Caption = 'Errors';
            Editable = false;
            FieldClass = FlowField;
            //CalcFormula = exist("Error Log Entry" where("Table ID" = const(82115), "Error No." = field("Error Log No.")));
        }
        field(106; CompanyID; Code[20])
        {
            Caption = 'CompanyID';
        }
        field(107; "Extraction Type"; Option)
        {
            Caption = 'Extraction Type';
            OptionMembers = BlackLine_NF_BlackLine_Account_Items,BlackLine_Bank,BlackLine_Customer,BlackLine_GL_Account_Balance,BlackLine_Vendor,BlackLine_IC_ACC,BlackLine_IC_BAL,BlackLine_IC_FIN,BlackLine_IC_FV,BlackLine_IC_INT,BlackLine_IC_PnL,BlackLine_Match;
            OptionCaption = 'BlackLine_NF_BlackLine_Account_Items,BlackLine_Bank,BlackLine_Customer,BlackLine_GL_Account_Balance,BlackLine_Vendor,BlackLine_IC_ACC,BlackLine_IC_BAL,BlackLine_IC_FIN,BlackLine_IC_FV,BlackLine_IC_INT,BlackLine_IC_PnL,BlackLine_Match';
        }
        field(108; "Execution Mode"; Option)
        {
            Caption = 'Execution Mode';
            OptionMembers = Full,Incremental;
            OptionCaption = 'Full,Incremental';
        }
        field(110; Batch_Guid; Guid)
        {
            Caption = 'Batch_Guid';
        }
        field(200; DateFilter; Code[30])
        {
            Caption = 'DateFilter';
        }
        field(210; NoFilter; Code[250])
        {
            Caption = 'NoFilter';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
    }


}
