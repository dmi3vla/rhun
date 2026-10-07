STRUCT
F GN_id, 8
F GN_name, 8
F GN_description, 8
F GN_object, 8
F GN_segment, 4
F GN_kind, 4
F GN_realm, 4
F GN_schema, 4
F GN_position, 12
ENDSTRUCT GN_SIZE
STRUCT
F GE_id, 8
F GE_a_name, 8
F GE_b_name, 8
F GE_kind, 4
F GE_a, 4
F GE_b, 4
ENDSTRUCT GE_SIZE
STRUCT
F GS_id, 4
F GS_name, 8
F GS_center, 12
F GS_half, 12
ENDSTRUCT GS_SIZE
STRUCT
F EV_label, 8
F EV_actor, 8
F EV_note, 8
F EV_versions, 16
F EV_active, VEC_SIZE
ENDSTRUCT EV_SIZE
STRUCT
F VP_id, 4
F VP_segment, 4
F VP_name, 8
F VP_kind, 4
F VP_realm, 4
F VP_x, 4
F VP_y, 4
F VP_z, 8
F VP_rx, 8
F VP_ry, 8
ENDSTRUCT VP_SIZE
STRUCT
F VE_a, 4
F VE_b, 4
F VE_kind, 4
F VE_sources, VEC_SIZE
ENDSTRUCT VE_SIZE
STRUCT
F GR_nodes, VEC_SIZE
F GR_edges, VEC_SIZE
F GR_segments, VEC_SIZE
F GR_events, VEC_SIZE
F GR_visible, VEC_SIZE
F GR_links, VEC_SIZE
F GR_fold, 4
F GR_selected, 4
F GR_event, 4
F GR_mode, 4
F GR_yaw, 4
F GR_pitch, 4
F GR_zoom, 4
F GR_drag, 4
F GR_mx, 4
F GR_my, 4
F GR_view_x, 4
F GR_view_y, 4
F GR_view_w, 4
F GR_view_h, 4
F GR_scale, 8
F GR_mid_x, 8
F GR_mid_y, 8
ENDSTRUCT GR_SIZE
