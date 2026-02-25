// utils/supabaseClient.js
// ─── MIGRATED: now re-exports from pgClient.js (Railway PostgreSQL) ───
// Supabase Storage is still connected for file operations.
// Database queries and Auth use the custom pgClient wrapper over Railway PostgreSQL.

import pgClient, { supabaseAdmin, supabasePublic, initPgClient } from "./pgClient.js";

// Initialize Supabase storage (async, non-blocking)
initPgClient(pgClient).catch((err) =>
  console.warn("Storage init warning:", err.message)
);

export { supabaseAdmin, supabasePublic };
export default pgClient;
