# Owned bounded comparison; refs are source view identities, never source edits.
STRUCT
F DN_id, 8
F DN_address, 8
F DN_label, 8
F DN_kind, 4
F DN_size, 4
F DN_capacity, 4
F DN_state, 4
F DN_confidence, 4
F DN_known, 4
F DN_ref, 8
F DN_frame, 8
F DN_addr64, 8
ENDSTRUCT DN_SIZE
STRUCT
F DE_from, 8
F DE_to, 8
F DE_kind, 4
ENDSTRUCT DE_SIZE
STRUCT
F DG_base, 8
F DG_snapshot, 8
F DG_profile, 4
F DG_complete, 4
F DG_nodes, VEC_SIZE
F DG_links, VEC_SIZE
F DG_scope, VEC_SIZE
ENDSTRUCT DG_SIZE
STRUCT
F DR_base, 4
F DR_target, 4
F DR_type, 4
F DR_status, 4
F DR_reason, 4
ENDSTRUCT DR_SIZE
STRUCT
F DF_base, 8
F DF_target, 8
F DF_results, VEC_SIZE
F DF_revision, 8
F DF_snapshot, 4
F DF_show, 4
F DF_filter, 4
F DF_cursor, 4
F DF_counts, 20
ENDSTRUCT DF_SIZE
