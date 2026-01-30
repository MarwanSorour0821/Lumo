# Supplements app (Phase 1: data foundation)

Supplement **knowledge base**: lookup by name or alias. Used later by the scheduler (suppsAI) to build schedules without calling OpenAI.

## Table

- **Database:** `supplements` table in Supabase (same Postgres as Django).
- **Model:** `Supplement` in `supplements/models.py` with `managed = False` (no migrations).

## API

Base path: **`/api/supplements/`**

### 1. Lookup one supplement (GET)

- **URL:** `GET /api/supplements/lookup/?name=Vitamin+D3`
- **Response (found):** `{ "found": true, "supplement": { ... } }`
- **Response (not found):** `404` with `{ "found": false, "name": "...", "message": "Supplement not found in knowledge base." }`
- Matching: exact `name` or any `aliases` (case-insensitive).

### 2. Lookup many supplements (POST)

- **URL:** `POST /api/supplements/lookup/`
- **Body:** `{ "names": ["Magnesium", "Vitamin D3", "Unknown Thing"] }`
- **Response:** `{ "supplements": [ {...}, {...}, null ], "unknown": ["Unknown Thing"] }`
- Order of `supplements` matches order of `names`; `null` where not found; `unknown` lists names that were not in the DB.

## Auth

- No auth required for Phase 1 (public knowledge base). You can add `IsAuthenticated` later if needed.
