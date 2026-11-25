table 50599 "Debug Log"
{
    Caption = 'Debug Log';
    DataClassification = CustomerContent;
    DataPerCompany = false;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            AutoIncrement = true;
        }
        field(2; "Created At"; DateTime)
        {
        }
        field(3; "Company Name"; Text[30])
        {
        }
        field(4; "User ID"; Code[50])
        {
        }
        field(5; "Source"; Text[100])
        {
        }
        field(6; "Debug Message"; Text[2048])
        {
        }
        field(7; "Session ID"; Integer)
        {
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
    }

    procedure AddLog(Source: Text; DebugMessage: Text)
    var
        DebugLog: Record "Debug Log";
    begin
        DebugLog.Init();
        DebugLog."Created At" := CurrentDateTime();
        DebugLog."Company Name" := CompanyName();
        DebugLog."User ID" := UserId();
        DebugLog."Source" :=
            CopyStr(Source, 1, MaxStrLen(DebugLog."Source"));
        DebugLog."Debug Message" :=
            CopyStr(DebugMessage, 1, MaxStrLen(DebugLog."Debug Message"));
        DebugLog."Session ID" := SessionId();
        DebugLog.Insert();
    end;
}