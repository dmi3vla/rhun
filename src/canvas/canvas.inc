# Owned scene and fixed-point viewport. Included after rhun.inc.
STRUCT
F SC_elements, VEC_SIZE
F SC_undo, VEC_SIZE
F SC_redo, VEC_SIZE
F SC_doc, 8
F SC_revision, 8
F SC_next_id, 8
F SC_selected, 8
F SC_zoom, 4
F SC_pan_x, 4
F SC_pan_y, 4
F SC_x, 4
F SC_y, 4
F SC_w, 4
F SC_h, 4
F SC_drag, 4
F SC_drag_x, 4
F SC_drag_y, 4
F SC_start_x, 4
F SC_start_y, 4
F SC_tool, 4
F SC_edit, TF_SIZE
ENDSTRUCT SC_SIZE
STRUCT
F CE_id, 8
F CE_kind, 4
F CE_x, 4
F CE_y, 4
F CE_w, 4
F CE_h, 4
F CE_color, 4
F CE_text, 8
F CE_from, 8
F CE_to, 8
F CE_frame, 8
F CE_group, 8
F CE_seed, 8
F CE_angle, 4
F CE_pad, 4
ENDSTRUCT CE_SIZE
.equ CT_SELECT, 0
.equ CT_RECT, 1
.equ CT_ELLIPSE, 2
.equ CT_ARROW, 3
.equ CT_TEXT, 4
.equ CT_FRAME, 5
.equ CT_LINE, 6
.equ CT_STROKE, 7
