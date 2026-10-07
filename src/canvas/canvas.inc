# Owned scene and fixed-point viewport. Included after rhun.inc.
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
F CE_flags, 4
F CE_role, 8
F CE_xid, 8
F CE_raw, 8
F CE_image, 8
F CE_gxid, 8
F CE_bitmap, 8
F CE_roughness, 4
F CE_fill, 4
F CE_fontsize, 4
F CE_reserved, 4
F CE_points, VEC_SIZE
ENDSTRUCT CE_SIZE
STRUCT
F SC_elements, VEC_SIZE
F SC_undo, VEC_SIZE
F SC_redo, VEC_SIZE
F SC_doc, 8
F SC_exchange, 8
F SC_ui, 8
F SC_graph, 8
F SC_graph_view, 8
F SC_generated, 8
F SC_mode, 4
F SC_proposal, 8
F SC_proposal_selected, 8
F SC_fold, VEC_SIZE
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
F SC_hash, 8
F SC_saved_hash, 8
F SC_bytes, 8
F SC_gesture, 4
F SC_gx, 4
F SC_gy, 4
F SC_dx, 4
F SC_dy, 4
F SC_node_type, 4
F SC_before, 8
F SC_text_id, 8
F SC_preview, CE_SIZE
F SC_edit, TF_SIZE
ENDSTRUCT SC_SIZE
.equ CT_SELECT, 0
.equ CT_RECT, 1
.equ CT_ELLIPSE, 2
.equ CT_ARROW, 3
.equ CT_TEXT, 4
.equ CT_FRAME, 5
.equ CT_LINE, 6
.equ CT_STROKE, 7

.equ CT_IMAGE, 8
.equ CT_UNSUPPORTED, 9

STRUCT
F UC_id, 8
F UC_source, 8
F UC_parent, 8
F UC_type, 4
F UC_width, 4
F UC_height, 4
F UC_padding, 4
F UC_gap, 4
F UC_text, 8
F UC_action, 8
F UC_x, 4
F UC_y, 4
F UC_w, 4
F UC_h, 4
ENDSTRUCT UC_SIZE
STRUCT
F UM_nodes, VEC_SIZE
F UM_root, 8
F UM_revision, 8
ENDSTRUCT UM_SIZE
.equ U_ROW, 0
.equ U_COLUMN, 1
.equ U_CARD, 2
.equ U_LIST, 3
.equ U_TEXT, 4
.equ U_BUTTON, 5
.equ U_INPUT, 6

STRUCT
F PO_kind, 4
F PO_selected, 4
F PO_id, 8
F PO_raw, 8
ENDSTRUCT PO_SIZE
STRUCT
F CP_ops, VEC_SIZE
F CP_revision, 8
F CP_explanation, 8
F CP_candidate, 8
ENDSTRUCT CP_SIZE
