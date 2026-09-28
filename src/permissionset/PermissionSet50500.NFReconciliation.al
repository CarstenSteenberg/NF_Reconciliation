permissionset 50500 "NF Reconciliation"
{
    Assignable = true;
    Caption = 'G/L Reconciliation';

    Permissions =
        tabledata "Reconciliation Parm Buffer" = RIMD,
        tabledata "Reconciliation Buffer" = RIMD,
        tabledata "Recon. G/L Outbound Entry" = RIMD,
        tabledata "Recon Master Outb. Entry" = RIMD;
}