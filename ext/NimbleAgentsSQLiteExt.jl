module NimbleAgentsSQLiteExt

using DBInterface: DBInterface
using JSON3: JSON3
using NimbleAgents
using SQLite: SQLite

import NimbleAgents:
    Artifact,
    MemoryEntry,
    Session,
    _artifact_to_dict,
    _dict_to_artifact,
    _dict_to_msg,
    _keyword_score,
    _msg_to_dict,
    _resolve_cutoff,
    _safe_state,
    add_memory!,
    cleanup!,
    close!,
    delete_memory!,
    list,
    list_memories,
    load,
    save!,
    search_memory,
    store_artifacts_dir

include("../src/storage/sqlite_store.jl")
include("../src/storage/sqlite_memory.jl")

end
