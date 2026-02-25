// scripts/clean-dump.js — Clean Supabase-specific references from pg_dump output
import fs from 'fs';

let sql = fs.readFileSync('supabase_dump.sql', 'utf8');

// 1. Replace extensions.uuid_generate_v4() with gen_random_uuid() (built-in since PG 13)
sql = sql.replace(/extensions\.uuid_generate_v4\(\)/g, 'gen_random_uuid()');

// 2. Remove references to "extensions" schema
sql = sql.replace(/CREATE SCHEMA extensions;/g, '-- removed: CREATE SCHEMA extensions');

// 3. Remove GRANT/REVOKE statements referencing Supabase roles
sql = sql.replace(/^(GRANT|REVOKE).*\b(anon|authenticated|service_role|supabase_admin|dashboard_user|supabase_auth_admin|supabase_storage_admin|pgsodium_keyholder|pgsodium_keyiduser|pgsodium_keymaker|pgbouncer|supabase_read_only_user)\b.*$/gm, '-- removed supabase role grant');

// 4. Remove ALTER DEFAULT PRIVILEGES for Supabase roles
sql = sql.replace(/^ALTER DEFAULT PRIVILEGES.*\b(anon|authenticated|service_role|supabase_admin)\b.*$/gm, '-- removed supabase default privileges');

// 5. Replace public.vector with TEXT (if vector extension not available)
sql = sql.replace(/public\.vector(\(\d+\))?/g, 'TEXT');
sql = sql.replace(/\bvector(\(\d+\))?/g, 'TEXT');

// 6. Remove CREATE EXTENSION statements for Supabase-specific extensions
sql = sql.replace(/^CREATE EXTENSION IF NOT EXISTS.*$/gm, '-- removed extension');

// 7. Remove \connect and other psql meta-commands that may cause issues on Windows
sql = sql.replace(/^\\connect.*$/gm, '-- removed connect');

// 8. Remove COMMENT ON EXTENSION statements
sql = sql.replace(/^COMMENT ON EXTENSION.*$/gm, '-- removed extension comment');

// 9. Remove SET statements that reference non-existent schemas in search_path
// Keep the basic ones

// 10. Remove POLICY statements (Supabase RLS)
sql = sql.replace(/^CREATE POLICY.*$/gm, '-- removed policy');
sql = sql.replace(/^ALTER TABLE.*ENABLE ROW LEVEL SECURITY.*$/gm, '-- removed RLS');

// 11. Handle MATERIALIZED VIEW refresh that references missing columns
// Keep these as-is, they'll just error if the view doesn't exist

fs.writeFileSync('supabase_dump_clean.sql', sql, 'utf8');

console.log('✅ Cleaned dump saved to supabase_dump_clean.sql');
console.log(`   Original: ${(fs.statSync('supabase_dump.sql').size / 1024).toFixed(1)} KB`);
console.log(`   Cleaned:  ${(fs.statSync('supabase_dump_clean.sql').size / 1024).toFixed(1)} KB`);
