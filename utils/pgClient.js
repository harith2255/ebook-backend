// utils/pgClient.js — Supabase-compatible query builder over raw pg
// Allows existing code like:
//   supabase.from("profiles").select("*").eq("id", userId).single()
// to work unchanged with Railway PostgreSQL.

import pool from "./db.js";

/* =========================================================================
   QueryBuilder — chainable, mimics @supabase/supabase-js PostgREST client
   ========================================================================= */
class QueryBuilder {
  constructor(table) {
    this._table = table;
    this._operation = "select"; // select | insert | update | delete | upsert
    this._columns = "*";
    this._filters = [];       // { sql, value }
    this._orFilters = [];     // raw OR filter strings
    this._orderClauses = [];
    this._limitVal = null;
    this._offsetVal = null;
    this._rangeFrom = null;
    this._rangeTo = null;
    this._singleRow = false;
    this._maybeSingle = false;
    this._payload = null;
    this._conflictTarget = null;
    this._returnData = false;
    this._countMode = null;    // null | "exact"
    this._headOnly = false;    // true → return count only, no rows
  }

  /* ----- operations ----- */

  select(columns, opts) {
    if (!["insert", "update", "delete", "upsert"].includes(this._operation)) {
      this._operation = "select";
    }
    this._returnData = true;
    this._columns = columns || "*";
    if (opts?.count === "exact") this._countMode = "exact";
    if (opts?.head) this._headOnly = true;
    return this;
  }

  insert(payload) {
    this._operation = "insert";
    this._payload = payload;
    this._returnData = true;
    return this;
  }

  update(payload) {
    this._operation = "update";
    this._payload = payload;
    return this;
  }

  delete(opts) {
    this._operation = "delete";
    if (opts?.count === "exact") this._countMode = "exact";
    return this;
  }

  upsert(payload, opts) {
    this._operation = "upsert";
    this._payload = payload;
    this._conflictTarget = opts?.onConflict || null;
    this._returnData = true;
    return this;
  }

  /* ----- filters ----- */

  eq(col, val) {
    this._filters.push({ sql: `"${col}" = $__`, value: val });
    return this;
  }

  neq(col, val) {
    this._filters.push({ sql: `"${col}" != $__`, value: val });
    return this;
  }

  gt(col, val) {
    this._filters.push({ sql: `"${col}" > $__`, value: val });
    return this;
  }

  gte(col, val) {
    this._filters.push({ sql: `"${col}" >= $__`, value: val });
    return this;
  }

  lt(col, val) {
    this._filters.push({ sql: `"${col}" < $__`, value: val });
    return this;
  }

  lte(col, val) {
    this._filters.push({ sql: `"${col}" <= $__`, value: val });
    return this;
  }

  ilike(col, val) {
    this._filters.push({ sql: `"${col}" ILIKE $__`, value: val });
    return this;
  }

  in(col, arr) {
    if (!arr || arr.length === 0) {
      // Empty IN → always false
      this._filters.push({ sql: `FALSE`, value: null, noParam: true });
      return this;
    }
    this._filters.push({ sql: `"${col}" = ANY($__)`, value: arr });
    return this;
  }

  // .not("col", "is", null)  → "col" IS NOT NULL
  not(col, operator, val) {
    if (operator === "is" && val === null) {
      this._filters.push({ sql: `"${col}" IS NOT NULL`, value: null, noParam: true });
    } else {
      this._filters.push({ sql: `NOT ("${col}" = $__)`, value: val });
    }
    return this;
  }

  // .is("col", null)  → "col" IS NULL
  is(col, val) {
    if (val === null) {
      this._filters.push({ sql: `"${col}" IS NULL`, value: null, noParam: true });
    } else {
      this._filters.push({ sql: `"${col}" = $__`, value: val });
    }
    return this;
  }

  // .or("full_name.ilike.%search%,email.ilike.%search%")
  or(filterString) {
    this._orFilters.push(filterString);
    return this;
  }

  /* ----- modifiers ----- */

  order(col, opts) {
    const dir = opts?.ascending === false ? "DESC" : "ASC";
    this._orderClauses.push(`"${col}" ${dir}`);
    return this;
  }

  limit(n) {
    this._limitVal = n;
    return this;
  }

  range(from, to) {
    this._rangeFrom = from;
    this._rangeTo = to;
    return this;
  }

  single() {
    this._singleRow = true;
    this._returnData = true;
    return this;
  }

  maybeSingle() {
    this._maybeSingle = true;
    this._returnData = true;
    return this;
  }

  /* ----- execute on await / then ----- */

  then(resolve, reject) {
    return this._execute().then(resolve, reject);
  }

  async _execute() {
    try {
      switch (this._operation) {
        case "select":
          return await this._execSelect();
        case "insert":
          return await this._execInsert();
        case "update":
          return await this._execUpdate();
        case "delete":
          return await this._execDelete();
        case "upsert":
          return await this._execUpsert();
        default:
          return { data: null, error: { message: `Unknown operation: ${this._operation}` } };
      }
    } catch (err) {
      return { data: null, error: { message: err.message } };
    }
  }

  /* ------------------------------------------------------------------ */
  /*  INTERNAL: build WHERE clause                                       */
  /* ------------------------------------------------------------------ */
  _buildWhere(params) {
    const parts = [];

    for (const f of this._filters) {
      if (f.noParam) {
        parts.push(f.sql);
      } else {
        params.push(f.value);
        parts.push(f.sql.replace("$__", `$${params.length}`));
      }
    }

    // Handle .or() — Supabase format: "col.op.val,col.op.val"
    for (const orStr of this._orFilters) {
      const orParts = this._parseOrFilter(orStr, params);
      if (orParts.length) parts.push(`(${orParts.join(" OR ")})`);
    }

    return parts.length ? `WHERE ${parts.join(" AND ")}` : "";
  }

  _parseOrFilter(str, params) {
    const conditions = [];
    // Split on commas that are NOT inside parentheses
    const items = str.split(",");

    for (const item of items) {
      const dotParts = item.trim().split(".");
      if (dotParts.length < 3) continue;

      const col = dotParts[0];
      const op = dotParts[1];
      const val = dotParts.slice(2).join(".");

      switch (op) {
        case "eq":
          params.push(val);
          conditions.push(`"${col}" = $${params.length}`);
          break;
        case "neq":
          params.push(val);
          conditions.push(`"${col}" != $${params.length}`);
          break;
        case "ilike":
          params.push(val);
          conditions.push(`"${col}" ILIKE $${params.length}`);
          break;
        case "like":
          params.push(val);
          conditions.push(`"${col}" LIKE $${params.length}`);
          break;
        case "gt":
          params.push(val);
          conditions.push(`"${col}" > $${params.length}`);
          break;
        case "gte":
          params.push(val);
          conditions.push(`"${col}" >= $${params.length}`);
          break;
        case "lt":
          params.push(val);
          conditions.push(`"${col}" < $${params.length}`);
          break;
        case "lte":
          params.push(val);
          conditions.push(`"${col}" <= $${params.length}`);
          break;
        case "is":
          if (val === "null") {
            conditions.push(`"${col}" IS NULL`);
          } else {
            conditions.push(`"${col}" IS NOT NULL`);
          }
          break;
        default:
          params.push(val);
          conditions.push(`"${col}" = $${params.length}`);
      }
    }

    return conditions;
  }

  _buildOrderBy() {
    return this._orderClauses.length
      ? `ORDER BY ${this._orderClauses.join(", ")}`
      : "";
  }

  _buildLimit() {
    if (this._rangeFrom !== null && this._rangeTo !== null) {
      const limit = this._rangeTo - this._rangeFrom + 1;
      return `LIMIT ${limit} OFFSET ${this._rangeFrom}`;
    }
    let s = "";
    if (this._limitVal !== null) s += `LIMIT ${this._limitVal}`;
    if (this._offsetVal !== null) s += ` OFFSET ${this._offsetVal}`;
    if (this._singleRow || this._maybeSingle) s = s || "LIMIT 1";
    return s;
  }

  /* ------------------------------------------------------------------ */
  /*  SELECT  (with FK join support)                                      */
  /* ------------------------------------------------------------------ */
  async _execSelect() {
    const params = [];
    const where = this._buildWhere(params);
    const order = this._buildOrderBy();
    const limit = this._buildLimit();

    // Parse FK joins from columns
    // Patterns: "ebooks(id, title, author)" or "plan:subscription_plans(*)"
    let rawCols = this._columns.trim();
    const fkJoins = [];
    let plainCols = [];

    if (rawCols !== "*") {
      // Split by commas, but NOT commas inside parentheses
      const parts = this._splitTopLevel(rawCols);

      for (const part of parts) {
        const trimmed = part.trim();
        // Match FK join: optional_alias:table_name!optional_modifier(columns)
        const fkMatch = trimmed.match(/^(?:(\w+):)?([a-zA-Z0-9_!]+)\s*\(([\s\S]+)\)$/);
        if (fkMatch) {
          const rawTable = fkMatch[2];
          const joinTable = rawTable.split("!")[0]; // strip !inner or !fk modifier
          const alias = fkMatch[1] || joinTable; 
          const joinCols = fkMatch[3].trim();
          fkJoins.push({ alias, joinTable, joinCols });
        } else {
          plainCols.push(trimmed);
        }
      }
    } else {
      plainCols.push("*");
    }

    let countResult = null;

    if (this._countMode === "exact") {
      const countSql = `SELECT COUNT(*) AS total FROM "${this._table}" ${where}`;
      const countRes = await pool.query(countSql, [...params]);
      countResult = parseInt(countRes.rows[0]?.total || "0", 10);

      if (this._headOnly) {
        return { data: null, count: countResult, error: null };
      }
    }

    // Build the SQL
    if (fkJoins.length === 0) {
      // Simple select — no FK joins
      const cols = plainCols.join(", ");
      const sql = `SELECT ${cols} FROM "${this._table}" ${where} ${order} ${limit}`.trim();
      const result = await pool.query(sql, params);

      return this._formatResult(result.rows, countResult);
    }

    // --- FK join mode ---
    // Build SELECT with LEFT JOINs and JSON aggregation
    const mainAlias = "t0";
    const selectParts = [];

    // Main table columns
    if (plainCols.length === 0 || (plainCols.length === 1 && plainCols[0] === "")) {
      selectParts.push(`${mainAlias}.*`);
    } else {
      for (const col of plainCols) {
        if (col === "*") {
          selectParts.push(`${mainAlias}.*`);
        } else if (col) {
          selectParts.push(`${mainAlias}."${col.trim()}"`);
        }
      }
    }

    const joinClauses = [];
    for (let i = 0; i < fkJoins.length; i++) {
      const fk = fkJoins[i];
      const joinAlias = `j${i}`;

      let baseCol = fk.joinTable.replace(/s$/, "") + "_id";
      
      // Known irregular foreign keys in this schema
      const fkMap = {
        "ebooks": "book_id",
        "subscription_plans": "plan_id",
        "categories": "category_id",
        "mock_tests": "test_id",
        "payments_transactions": "payment_id"
      };
      
      let fkCol = fkMap[fk.joinTable] || baseCol;
      
      // Only apply alias logic if we don't have a direct map hit and alias != target
      if (!fkMap[fk.joinTable] && fk.alias !== fk.joinTable) {
         fkCol = `${fk.alias}_id`;
      }

      // Check reverse joins (1-to-many relationships)
      const reverseJoinMap = {
        "mock_tests->mock_attempts": "test_id",
        "mock_tests->mock_test_questions": "test_id",
      };

      const reverseJoinCol = reverseJoinMap[`${this._table}->${fk.joinTable}`];

      // Build the JOIN ON clause
      let onClause;
      if (reverseJoinCol) {
        onClause = `${joinAlias}."${reverseJoinCol}" = ${mainAlias}."id"`;
      } else {
        onClause = `${mainAlias}."${fkCol}" = ${joinAlias}."id"`;
      }

      joinClauses.push(`LEFT JOIN "${fk.joinTable}" ${joinAlias} ON ${onClause}`);

      // Build joined columns as JSON
      if (fk.joinCols === "*") {
        selectParts.push(`row_to_json(${joinAlias}) AS "${fk.alias}"`);
      } else {
        const jCols = fk.joinCols.split(",").map(c => c.trim());
        const jsonParts = jCols.map(c => `'${c}', ${joinAlias}."${c}"`).join(", ");
        selectParts.push(`json_build_object(${jsonParts}) AS "${fk.alias}"`);
      }
    }

    // Fix WHERE to reference main alias
    let aliasedWhere = where;
    if (aliasedWhere) {
      // Add table alias to column references in WHERE that don't already have one
      aliasedWhere = aliasedWhere.replace(/"(\w+)"\s*(=|!=|>|>=|<|<=|ILIKE|LIKE|IS|= ANY)/g, 
        `${mainAlias}."$1" $2`);
    }

    // Fix ORDER BY to reference main alias
    let aliasedOrder = order;
    if (aliasedOrder) {
      aliasedOrder = aliasedOrder.replace(/"(\w+)"\s*(ASC|DESC)/g, `${mainAlias}."$1" $2`);
    }

    const sql = `SELECT ${selectParts.join(", ")} FROM "${this._table}" ${mainAlias} ${joinClauses.join(" ")} ${aliasedWhere} ${aliasedOrder} ${limit}`.trim();

    const result = await pool.query(sql, params);

    return this._formatResult(result.rows, countResult);
  }

  /* Split string by commas not inside parentheses */
  _splitTopLevel(str) {
    const parts = [];
    let depth = 0;
    let current = "";
    for (const ch of str) {
      if (ch === "(") depth++;
      else if (ch === ")") depth--;
      if (ch === "," && depth === 0) {
        parts.push(current);
        current = "";
      } else {
        current += ch;
      }
    }
    if (current) parts.push(current);
    return parts;
  }

  _formatResult(rows, countResult) {
    let data = rows;
    if (this._singleRow) {
      if (data.length === 0) {
        return { data: null, error: { message: "Row not found", code: "PGRST116" } };
      }
      data = data[0];
    } else if (this._maybeSingle) {
      data = data.length > 0 ? data[0] : null;
    }

    const res = { data, error: null };
    if (countResult !== null) res.count = countResult;
    return res;
  }

  /* ------------------------------------------------------------------ */
  /*  INSERT                                                             */
  /* ------------------------------------------------------------------ */
  async _execInsert() {
    const rows = Array.isArray(this._payload) ? this._payload : [this._payload];
    if (rows.length === 0) return { data: [], error: null };

    const keys = Object.keys(rows[0]);
    const colNames = keys.map((k) => `"${k}"`).join(", ");

    const params = [];
    const valueSets = rows.map((row) => {
      const placeholders = keys.map((k) => {
        params.push(row[k]);
        return `$${params.length}`;
      });
      return `(${placeholders.join(", ")})`;
    });

    const sql = `INSERT INTO "${this._table}" (${colNames}) VALUES ${valueSets.join(", ")} RETURNING *`;

    const result = await pool.query(sql, params);
    let data = result.rows;

    if (this._singleRow) data = data[0] || null;
    else if (this._maybeSingle) data = data[0] || null;

    return { data, error: null };
  }

  /* ------------------------------------------------------------------ */
  /*  UPDATE                                                             */
  /* ------------------------------------------------------------------ */
  async _execUpdate() {
    const keys = Object.keys(this._payload);
    const params = [];
    const setClauses = keys.map((k) => {
      params.push(this._payload[k]);
      return `"${k}" = $${params.length}`;
    });

    const where = this._buildWhere(params);

    const returning = this._returnData ? "RETURNING *" : "";
    const sql = `UPDATE "${this._table}" SET ${setClauses.join(", ")} ${where} ${returning}`.trim();

    const result = await pool.query(sql, params);
    let data = result.rows;

    if (this._singleRow) data = data[0] || null;
    else if (this._maybeSingle) data = data[0] || null;
    else if (!this._returnData) data = null;

    return { data, error: null };
  }

  /* ------------------------------------------------------------------ */
  /*  DELETE                                                             */
  /* ------------------------------------------------------------------ */
  async _execDelete() {
    const params = [];
    const where = this._buildWhere(params);

    let countResult = null;
    if (this._countMode === "exact") {
      const countSql = `SELECT COUNT(*) AS total FROM "${this._table}" ${where}`;
      const countRes = await pool.query(countSql, [...params]);
      countResult = parseInt(countRes.rows[0]?.total || "0", 10);
    }

    const sql = `DELETE FROM "${this._table}" ${where}`.trim();
    await pool.query(sql, params);

    const res = { data: null, error: null };
    if (countResult !== null) res.count = countResult;
    return res;
  }

  /* ------------------------------------------------------------------ */
  /*  UPSERT  (INSERT … ON CONFLICT … DO UPDATE)                        */
  /* ------------------------------------------------------------------ */
  async _execUpsert() {
    const rows = Array.isArray(this._payload) ? this._payload : [this._payload];
    if (rows.length === 0) return { data: [], error: null };

    const keys = Object.keys(rows[0]);
    const colNames = keys.map((k) => `"${k}"`).join(", ");

    const params = [];
    const valueSets = rows.map((row) => {
      const placeholders = keys.map((k) => {
        params.push(row[k]);
        return `$${params.length}`;
      });
      return `(${placeholders.join(", ")})`;
    });

    const conflict = this._conflictTarget
      ? `(${this._conflictTarget.split(",").map((c) => `"${c.trim()}"`).join(", ")})`
      : `("id")`;

    const updateClauses = keys.map((k) => `"${k}" = EXCLUDED."${k}"`).join(", ");

    const sql = `INSERT INTO "${this._table}" (${colNames}) VALUES ${valueSets.join(", ")}
      ON CONFLICT ${conflict} DO UPDATE SET ${updateClauses}
      RETURNING *`;

    const result = await pool.query(sql, params);
    let data = result.rows;

    if (this._singleRow) data = data[0] || null;
    else if (this._maybeSingle) data = data[0] || null;

    return { data, error: null };
  }
}


/* =========================================================================
   PgClient — drop-in replacement for the Supabase client
   ========================================================================= */
class PgClient {
  constructor() {
    // Keep a reference to supabase storage client (lazy-loaded)
    this._storageClient = null;
    this._supabaseClientForStorage = null;
  }

  /** Database query builder — matches supabase.from("table") */
  from(table) {
    return new QueryBuilder(table);
  }

  /** RPC calls — matches supabase.rpc("function_name", { arg1, arg2 }) */
  async rpc(fnName, args = {}) {
    try {
      const keys = Object.keys(args);
      const params = keys.map((k) => args[k]);
      const placeholders = keys.map((_, i) => `$${i + 1}`);

      // Call as: SELECT * FROM function_name($1, $2, ...)
      // Named parameters: SELECT * FROM function_name(arg1 := $1, arg2 := $2, ...)
      const namedParams = keys
        .map((k, i) => `"${k}" := $${i + 1}`)
        .join(", ");

      const sql = `SELECT * FROM "${fnName}"(${namedParams})`;
      const result = await pool.query(sql, params);

      return { data: result.rows, error: null };
    } catch (err) {
      return { data: null, error: { message: err.message } };
    }
  }

  /** Storage accessor — proxies to the real Supabase client for file ops */
  get storage() {
    if (!this._storageClient) {
      this._initStorage();
    }
    return this._storageClient;
  }

  _initStorage() {
    // Lazy-import the Supabase client just for storage operations
    // We keep Supabase connected ONLY for file storage (buckets)
    try {
      const { createClient } = await_import_supabase();
      const url = process.env.SUPABASE_URL;
      const key = process.env.SUPABASE_SERVICE_ROLE_KEY;

      if (url && key) {
        this._supabaseClientForStorage = createClient(url, key, {
          auth: {
            autoRefreshToken: false,
            persistSession: false,
            detectSessionInUrl: false,
          },
        });
        this._storageClient = this._supabaseClientForStorage.storage;
      } else {
        console.warn("⚠️ SUPABASE_URL/SUPABASE_SERVICE_ROLE_KEY not set — storage operations will fail");
        this._storageClient = createStorageFallback();
      }
    } catch (err) {
      console.warn("⚠️ Could not init Supabase storage:", err.message);
      this._storageClient = createStorageFallback();
    }
  }

  /** Auth namespace — stub that redirects to custom JWT auth */
  get auth() {
    return {
      admin: {
        // These are replaced by direct DB queries in the controllers
        createUser: notSupported("auth.admin.createUser"),
        updateUserById: notSupported("auth.admin.updateUserById"),
        deleteUser: notSupported("auth.admin.deleteUser"),
        getUserById: async (id) => {
          try {
            const result = await pool.query(
              `SELECT id, email, role, full_name, first_name, last_name, created_at FROM "profiles" WHERE id = $1`,
              [id]
            );
            if (result.rows.length === 0) {
              return { data: { user: null }, error: { message: "User not found" } };
            }
            const row = result.rows[0];
            return {
              data: {
                user: {
                  id: row.id,
                  email: row.email,
                  user_metadata: {
                    role: row.role,
                    full_name: row.full_name,
                    first_name: row.first_name,
                    last_name: row.last_name,
                  },
                },
              },
              error: null,
            };
          } catch (err) {
            return { data: { user: null }, error: { message: err.message } };
          }
        },
        listUsers: async (opts = {}) => {
          try {
            const page = opts.page || 1;
            const perPage = opts.perPage || 100;
            const offset = (page - 1) * perPage;
            const result = await pool.query(
              `SELECT id, email, role, full_name, first_name, last_name, created_at FROM "profiles" ORDER BY created_at DESC LIMIT $1 OFFSET $2`,
              [perPage, offset]
            );
            return {
              data: { users: result.rows.map(mapRowToUser) },
              error: null,
            };
          } catch (err) {
            return { data: { users: [] }, error: { message: err.message } };
          }
        },
      },
      getUser: async (token) => {
        // This should be replaced by JWT verification in middleware
        return { data: { user: null }, error: { message: "Use JWT verification instead" } };
      },
      signInWithPassword: async () => {
        return { data: null, error: { message: "Use custom login controller instead" } };
      },
    };
  }
}

/* Helpers */

function mapRowToUser(row) {
  return {
    id: row.id,
    email: row.email,
    user_metadata: {
      role: row.role,
      full_name: row.full_name,
      first_name: row.first_name,
      last_name: row.last_name,
    },
  };
}

function notSupported(method) {
  return async () => {
    console.warn(`⚠️ ${method} is not supported — use direct DB queries instead`);
    return { data: null, error: { message: `${method} not supported in PostgreSQL mode` } };
  };
}

// Synchronous import helper for Supabase (only for storage)
let _supabaseModule = null;
function await_import_supabase() {
  if (!_supabaseModule) {
    // Dynamic import won't work synchronously in _initStorage,
    // so we do a lazy require-style approach
    try {
      // Since we use ESM, we pre-import at the top level
      _supabaseModule = null; // Will be set by init()
    } catch (e) {
      // fallback
    }
  }
  return _supabaseModule;
}

function createStorageFallback() {
  const notAvailable = () => {
    throw new Error("Supabase storage not available — set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY");
  };
  return {
    from: () => ({
      upload: notAvailable,
      download: notAvailable,
      remove: notAvailable,
      getPublicUrl: notAvailable,
      createSignedUrl: notAvailable,
    }),
  };
}

/* =========================================================================
   Initialize & Export
   ========================================================================= */
let _storageInited = false;

export async function initPgClient(pgClient) {
  if (_storageInited) return;
  _storageInited = true;

  try {
    const supabaseModule = await import("@supabase/supabase-js");
    const url = process.env.SUPABASE_URL;
    const key = process.env.SUPABASE_SERVICE_ROLE_KEY;

    if (url && key) {
      const storageClient = supabaseModule.createClient(url, key, {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
          detectSessionInUrl: false,
        },
      });
      pgClient._storageClient = storageClient.storage;
      console.log("✅ Supabase Storage connected (for file operations)");
    }
  } catch (err) {
    console.warn("⚠️ Supabase Storage init failed:", err.message);
    pgClient._storageClient = createStorageFallback();
  }
}

// Create singleton instances
const pgClient = new PgClient();

// Named exports to match existing import patterns
export const supabaseAdmin = pgClient;
export const supabasePublic = pgClient;
export default pgClient;
