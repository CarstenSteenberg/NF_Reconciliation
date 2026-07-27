table 50500 "Reconciliation Parm Buffer"
{
    DataClassification = ToBeClassified;
    DataPerCompany = false;

    fields
    {
        field(1; GUID; Guid)
        {
            Caption = 'GUID';
        }
        field(2; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
        }
        field(10; "Extraction Type"; Option)
        {
            Caption = 'Extraction Type';
            OptionMembers = BlackLine_NF_BlackLine_Account_Items,BlackLine_Bank,BlackLine_Customer,BlackLine_GL_Account_Balance,BlackLine_Vendor,BlackLine_IC_ACC,BlackLine_IC_BAL,BlackLine_IC_FIN,BlackLine_IC_FV,BlackLine_IC_INT,BlackLine_IC_PnL,BlackLine_Match;
            OptionCaption = 'BlackLine_NF_BlackLine_Account_Items,BlackLine_Bank,BlackLine_Customer,BlackLine_GL_Account_Balance,BlackLine_Vendor,BlackLine_IC_ACC,BlackLine_IC_BAL,BlackLine_IC_FIN,BlackLine_IC_FV,BlackLine_IC_INT,BlackLine_IC_PnL,BlackLine_Match';
        }
        field(11; "Execution Mode"; Option)
        {
            Caption = 'Execution Mode';
            OptionMembers = Full,Incremental;
            OptionCaption = 'Full,Incremental';
        }
        field(12; "Generate Output"; Boolean)
        {
            Caption = 'Generate Output';
        }
    }

    keys
    {
        key(PK; GUID, "Entry No.")
        {
            Clustered = true;
        }
    }


}
