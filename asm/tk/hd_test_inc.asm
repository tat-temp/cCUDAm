// Stub "hash" for the call-mechanism test: Rout = Rin + 0x1234. Empty-paren FUNCTION; the body
// uses the call-site param bases directly (must start with R/UR/P/C). B0 waits the LDG that filled Rin.
FUNCTION stubhash()
{
    [B0-----:R-:W-:-:S06]    IADD3 Rout0, Rin0, 0x1234, RZ
}
