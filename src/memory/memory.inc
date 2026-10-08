# Owned model. All strings copied; addresses are hex strings, never JSON doubles.
STRUCT
F ME_id, 8
F ME_address, 8
F ME_kind, 4
ENDSTRUCT ME_SIZE
STRUCT
F MN_id, 8
F MN_label, 8
F MN_address, 8
F MN_parent, 8
F MN_thread, 8
F MN_source, 8
F MN_kind, 4
F MN_size, 4
F MN_capacity, 4
F MN_state, 4
F MN_certainty, 4
F MN_viewid, 8
ENDSTRUCT MN_SIZE
STRUCT
F ML_from, 8
F ML_to, 8
F ML_kind, 4
F ML_a, 4
F ML_b, 4
ENDSTRUCT ML_SIZE
STRUCT
F MS_id, 8
F MS_thread, 8
F MS_pc, 8
F MS_sp, 8
F MS_bp, 8
F MS_label, 8
F MS_nodes, VEC_SIZE
F MS_links, VEC_SIZE
ENDSTRUCT MS_SIZE
STRUCT
F MM_binary, 8
F MM_allocator, 8
F MM_provenance, 4
F MM_entrypoints, VEC_SIZE
F MM_snapshots, VEC_SIZE
F MM_cursor, 4
F MM_mode, 4
F MM_selected, 4
F MM_camera_zoom, 4
F MM_camera_x, 4
F MM_camera_y, 4
F MM_graph_yaw, 4
F MM_graph_pitch, 4
F MM_graph_zoom, 4
F MM_revision, 8
F MM_scene, 8
F MM_graph, 8
ENDSTRUCT MM_SIZE
