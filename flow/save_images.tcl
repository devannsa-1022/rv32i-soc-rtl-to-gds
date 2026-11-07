# Saves layout images of a finished ORFS stage (run headless by
# flow/run.sh images <stage>). Writes <stage>_overview.png and
# <stage>_power.png to $IMAGE_DIR.
read_db $::env(ODB_FILE)

# ~1200 pixels across the die height
set height [ord::dbu_to_microns [[[ord::get_db_block] getBBox] getDY]]
set resolution [expr {$height / 1200.0}]

gui::clear_highlights -1
gui::clear_selections
gui::fit
gui::set_display_controls "*" visible false
gui::set_display_controls "Layers/*" visible true
gui::set_display_controls "Nets/*" visible true
gui::set_display_controls "Instances/*" visible true
gui::set_display_controls "Shape Types/*" visible true
gui::set_display_controls "Misc/Instances/*" visible false
gui::set_display_controls "Misc/Instances/Pins" visible true
gui::set_display_controls "Misc/Instances/Blockages" visible true
gui::set_display_controls "Misc/Scale bar" visible true
save_image -resolution $resolution $::env(IMAGE_DIR)/$::env(STAGE)_overview.png

# Power grid only: hide the cells and the signal/clock nets.
gui::set_display_controls "Instances/StdCells/*" visible false
gui::set_display_controls "Nets/Signal" visible false
gui::set_display_controls "Nets/Clock" visible false
save_image -resolution $resolution $::env(IMAGE_DIR)/$::env(STAGE)_power.png
