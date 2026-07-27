table 50503 "Recon Master Outb. Entry"
{
    DataPerCompany = false;
    Caption = 'Recon Master Outb. Entry';

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
        }

        field(10; Type; Option)
        {
            Caption = 'Type';
            OptionMembers = "G/L Account",Customer,Vendor,Bank;
            OptionCaption = 'G/L Account,Customer,Vendor,Bank';
        }

        field(11; "No."; Code[20])
        {
            Caption = 'No.';
            TableRelation =
                if (Type = const("G/L Account")) "G/L Account"
            else if (Type = const(Customer)) Customer
            else if (Type = const(Vendor)) Vendor
            else if (Type = const(Bank)) "Bank Account";
        }

        field(12; Name; Text[50])
        {
            Caption = 'Description';
        }

        field(13; Balance; Decimal)
        {
            Caption = 'Amount';
            AutoFormatType = 1;
        }

        field(14; Currency; Code[10])
        {
            Caption = 'Currency';
        }

        field(15; "Active Account"; Text[5])
        {
            Caption = 'Active Account';
        }

        field(16; "Any Activity in period"; Text[5])
        {
            Caption = 'Any Activity in period';
        }

        field(17; "Last Date of the period"; Date)
        {
            Caption = 'Last Date of the period';
        }

        field(18; "Balance (LCY)"; Decimal)
        {
            Caption = 'Amount (LCY)';
            AutoFormatType = 1;
        }

        field(19; "G/L Account"; Code[20])
        {
            Caption = 'G/L Account';
            TableRelation =
                if (Type = const("G/L Account")) "G/L Account"
            else if (Type = const(Customer)) Customer
            else if (Type = const(Vendor)) Vendor
            else if (Type = const(Bank)) "Bank Account";
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
            OptionMembers = Open,,,Error,,,Released,,,Exported;
            OptionCaption = 'Open,,,Error,,,Released,,,Exported';
        }

        field(105; Errors; Boolean)
        {
            Caption = 'Errors';
            FieldClass = FlowField;
            CalcFormula = exist("Error Log Entry" where(
                "Table ID" = const(82115),
                "Error No." = field("Error Log No.")));
            Editable = false;
        }

        field(106; CompanyID; Code[20])
        {
            Caption = 'CompanyID';
        }

        field(107; "Extraction Type"; Option)
        {
            Caption = 'Extraction Type';
            OptionMembers =
                BlackLine_NF_BlackLine_Account_Items,BlackLine_Bank,BlackLine_Customer,BlackLine_GL_Account_Balance,BlackLine_Vendor,BlackLine_IC_ACC,BlackLine_IC_BAL,BlackLine_IC_FIN,BlackLine_IC_FV,BlackLine_IC_INT,BlackLine_IC_PnL;
            OptionCaption =
                'BlackLine_NF_BlackLine_Account_Items,BlackLine_Bank,BlackLine_Customer,BlackLine_GL_Account_Balance,BlackLine_Vendor,BlackLine_IC_ACC,BlackLine_IC_BAL,BlackLine_IC_FIN,BlackLine_IC_FV,BlackLine_IC_INT,BlackLine_IC_PnL';
        }

        field(108; "Execution Mode"; Option)
        {
            Caption = 'Execution Mode';
            OptionMembers = Full,Incremental;
            OptionCaption = 'Full,Incremental';
        }

        field(110; Batch_Guid; Guid)
        {
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }

        key(Key1; "Export Date/Time", "Extraction Type")
        {
        }

        key(Key2; Batch_Guid, CompanyID, "No.")
        {
        }
    }

    trigger OnInsert()
    begin
        "Inserted By" := UserId();
        "Inserted Date/Time" := CurrentDateTime();
    end;
}
