table 50120 "Reconciliation Parm Buffer"
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

    /*
    Converted from NAV C/AL table export.

    Original documentation notes:
    2022-06-15 #3593734 Filudtræk til Blackline afstemning NF11.00.1.227
    2021-09-01 #2906058 BlackLine Performance NF11.00.1.195
    2021-04-26 #2712146 Blackline integration setup and open item NF11.00.1.193
    */
}
