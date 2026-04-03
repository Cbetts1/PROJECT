-- AURA Memory Database Schema
-- © 2026 Chris Betts | AIOSCPU Official | AI-generated, fully legal
--
-- This schema is used by aura-agent.py to persist AI agent memory
-- across sessions. It is initialised automatically at agent startup
-- via init_db() in aura-agent.py.
--
-- Apply manually with: sqlite3 /var/lib/aura/aura-memory.db < schema-memory.sql

-- ---------------------------------------------------------------------------
-- memory table
-- Stores arbitrary key/value pairs scoped by a logical namespace.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS memory (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    -- ISO-8601 UTC timestamp of when this entry was created
    created_at TEXT    NOT NULL,
    -- Logical namespace; e.g. "user", "system", "session", "task"
    scope      TEXT    NOT NULL,
    -- Key name within the scope
    key        TEXT    NOT NULL,
    -- Stored value (arbitrary UTF-8 string, may be JSON)
    value      TEXT    NOT NULL
);

-- Index for fast scope+key lookups (most common query pattern)
CREATE INDEX IF NOT EXISTS idx_memory_scope_key
    ON memory (scope, key);

-- Index for chronological recall within a scope
CREATE INDEX IF NOT EXISTS idx_memory_scope_created
    ON memory (scope, created_at);

-- ---------------------------------------------------------------------------
-- agent_log table (optional – for structured event recording)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS agent_log (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at TEXT    NOT NULL,
    event_type TEXT    NOT NULL,   -- e.g. "cmd", "error", "startup"
    detail     TEXT
);

CREATE INDEX IF NOT EXISTS idx_agent_log_event
    ON agent_log (event_type, created_at);
