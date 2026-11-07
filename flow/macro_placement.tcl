# Manual SRAM placement (core is x 40..1060, y 40..810; each macro 479.78 x 397.5 um).
#
# Both macros sit along the top of the core, leaving a 1020 x 340 um band
# underneath for the standard cells and a 40 um routing channel between them.
#   - Port 0 (read/write) pins are on the macro's bottom and left edges,
#     port 1 (read-only) pins on its top and right edges.
#   - imem: fetch uses port 1, so the macro is mirrored about X (MX) to turn
#     dout1/clk1 down toward the core logic. Its program-load pins (port 0)
#     then face the die's top edge.
#   - dmem: uses port 0 only, so R0 already has those pins facing down.
place_macro -macro_name imem0.sram0.macro -location {50 400} -orientation MX
place_macro -macro_name dmem0.sram0.macro -location {570.22 400} -orientation R0
