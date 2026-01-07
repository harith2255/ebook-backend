import supabase from "../utils/supabaseClient.js";
import { validate as isUUID } from "uuid";

/* ============================================================
   1️⃣  UNIFIED PURCHASE HANDLER (BOOKS + NOTES)
   POST /api/purchases/unified
   Body: { items: [{ id, type: "book" | "note" }] }
=============================================================== */

export const unifiedPurchase = async (req, res) => {
  try {
    const userId = req.user.id;

// 0️⃣ Block suspended users — READ-ONLY MODE
const { data: profile, error: profileErr } = await supabase
  .from("profiles")
  .select("account_status")
  .eq("id", userId)
  .single();
const { payment } = req.body;

// payment is OPTIONAL (required only for paid items)
const paymentId = payment?.payment_id || null;


if (profileErr) {
  return res.status(500).json({ error: "Failed to fetch account" });
}

if (profile?.account_status === "suspended") {
  return res.status(403).json({
    error: "Your account is suspended. Read-only mode enabled.",
    read_only: true
  });
}


    // user_id must be a UUID
    if (!userId || !isUUID(userId)) {
      return res.status(400).json({ error: "Invalid user id" });
    }

    const { items } = req.body;

    if (!items || !Array.isArray(items)) {
      return res.status(400).json({ error: "Invalid purchase payload" });
    }

    const results = [];
    const errors = [];

    for (const item of items) {
      try {
        if (!item?.id) {
          console.warn("⚠️ Skipping item with no ID:", item);
          errors.push({
            id: null,
            type: item?.type ?? "unknown",
            error: "Missing ID",
          });
          continue;
        }

if (item.type === "subscription") {
  if (!payment?.payment_id) {
    throw new Error("Subscription requires successful payment");
  }

  await processSubscriptionPurchase(userId, item.id);
  results.push({ type: "subscription", id: item.id, purchased: true });
  continue;
}



if (item.type === "writing") {
  await processWritingPurchase(userId, item.payload);
  results.push({ type: "writing", purchased: true });
  continue;
}
        // 📚 BOOK PURCHASE
        if (item.type === "book") {
          // book IDs should be UUIDs (ebooks.id)
          if (!isUUID(item.id)) {
            errors.push({
              id: item.id,
              type: "book",
              error: "Invalid book ID format (expected UUID)",
            });
            continue;
          }

         const result = await processBookPurchase(
  userId,
  item.id,
  paymentId // null for FREE books
);


          // remove from cart
          await supabase
            .from("user_cart")
            .delete()
            .eq("user_id", userId)
            .eq("book_id", item.id);

          results.push({
            type: "book",
            id: item.id,
            purchased: !result?.skipped,
            alreadyPurchased: !!result?.alreadyPurchased,
          });
          continue;
        }

        // 📝 NOTE PURCHASE
        if (item.type === "note") {
          const numericId = Number(item.id);
          if (!numericId) {
            errors.push({
              id: item.id,
              type: "note",
              error: "Invalid note ID (expected number)",
            });
            continue;
          }

          const result = await processNotePurchase(userId, numericId);

          // remove from cart
          await supabase
            .from("user_cart")
            .delete()
            .eq("user_id", userId)
            .eq("note_id", numericId);

          results.push({
            type: "note",
            id: numericId,
            purchased: !result?.skipped,
            alreadyPurchased: !!result?.alreadyPurchased,
          });
          continue;
        }

        // Unknown item type
        errors.push({
          id: item.id,
          type: item.type,
          error: "Unknown item type",
        });
      } catch (err) {
        console.error("Item purchase error:", err);
        errors.push({
          id: item.id,
          type: item.type,
          error: err.message || "Item purchase failed",
        });
      }
    }

    if (errors.length > 0) {
      // Multi-Status: some success, some failed
      return res.status(207).json({ results, errors });
    }

    return res.json({ success: true, results });
  } catch (err) {
    console.error("unifiedPurchase error:", err);
    return res.status(500).json({ error: "Server error processing purchase" });
  }
};
async function processSubscriptionPurchase(userId, planId) {
  const { data: plan } = await supabase
    .from("subscription_plans")
    .select("*")
    .eq("id", planId)
    .single();

  if (!plan) throw new Error("Invalid plan");

  const now = new Date();
  const expiresAt =
    plan.period === "monthly"
      ? new Date(now.setMonth(now.getMonth() + 1))
      : new Date(now.setFullYear(now.getFullYear() + 1));

  // expire old
  await supabase
    .from("user_subscriptions")
    .update({ status: "expired" })
    .eq("user_id", userId)
    .eq("status", "active");

  // create new
  await supabase.from("user_subscriptions").insert({
    user_id: userId,
    plan_id: plan.id,
    started_at: new Date().toISOString(),
    expires_at: expiresAt.toISOString(),
    status: "active",
  });
}
async function processWritingPurchase(userId, payload) {
  await supabase.from("writing_orders").insert({
    ...payload,
    user_id: userId,
    payment_success: true,
    payment_status: "Paid",
    paid_at: new Date().toISOString(),
    status: "Pending",
  });
}

/* ============================================================
   2️⃣ PROCESS BOOK PURCHASE — book_sales + user_library + REVENUE
   - bookId is UUID (ebooks.id)
   - revenue.item_id = bookId (UUID)
=============================================================== */
async function processBookPurchase(userId, bookId, paymentId = null)
 {
  if (!isUUID(userId)) throw new Error("Invalid userId");
  if (!isUUID(bookId)) throw new Error("Invalid bookId");

  // 1) Skip if already purchased
  const { data: exists, error: existsErr } = await supabase
    .from("book_sales")
    .select("id")
    .eq("user_id", userId)
    .eq("book_id", bookId)
    .maybeSingle();

  if (existsErr) throw existsErr;
  if (exists) return { alreadyPurchased: true };

  // 2) Get price from ebooks
  const { data: bookRow, error: priceErr } = await supabase
    .from("ebooks")
    .select("price")
    .eq("id", bookId)
    .single();

  if (priceErr) throw priceErr;

 const price = Number(bookRow?.price) || 0;

// 🚫 Paid book without payment → block
if (price > 0 && !paymentId) {
  throw new Error("Payment required for paid book");
}


  // 3) Insert into book_sales
  // ⚠️ IMPORTANT: book_sales.id is probably bigint/uuid with DEFAULT
  // -> DO NOT send id manually unless schema requires it.
  const { error: saleError } = await supabase.from("book_sales").insert({
    user_id: userId,
    book_id: bookId,
    purchased_at: new Date().toISOString(),
  });

  if (saleError) throw saleError;

  // 4) Ensure user_library entry
  const { data: libExists, error: libErrCheck } = await supabase
    .from("user_library")
    .select("id")
    .eq("user_id", userId)
    .eq("book_id", bookId)
    .maybeSingle();

  if (libErrCheck) {
    console.warn("user_library check failed:", libErrCheck.message);
  }

  if (!libExists) {
    // user_library.id is BIGINT with sequence -> DO NOT send id
    const { error: libErr } = await supabase.from("user_library").insert({
      user_id: userId,
      book_id: bookId, // uuid
      progress: 0,
      last_page: 1,
      added_at: new Date().toISOString(),
    });

    if (libErr) {
      console.warn("user_library insert failed:", libErr.message);
    }
  }

  // 5) Insert revenue: for books, use item_id (UUID), old_item_id = null
  const { error: revErr } = await supabase.from("revenue").insert({
    // id is bigint auto, don't send
    user_id: userId,
    amount: price,
    item_type: "book",
    item_id: bookId,      // uuid
    old_item_id: null,    // not used for books
    created_at: new Date().toISOString(),
   payment_id: payment?.payment_id || null
     // fill later if gateway is added
  });

  if (revErr) {
    console.error("Revenue insert failed (book):", revErr.message);
  }

  return { success: true };
}

/* ============================================================
   3️⃣ PROCESS NOTE PURCHASE — notes_purchase + REVENUE
   - noteId is integer (notes.id)
   - revenue.old_item_id = noteId (integer)
   - revenue.item_id stays NULL
=============================================================== */
async function processNotePurchase(userId, noteId) {
  if (!isUUID(userId)) throw new Error("Invalid userId");
  const numericId = Number(noteId);
  if (!numericId) return { skipped: true };

  // 1) Skip if already purchased
  const { data: exists, error: existsErr } = await supabase
    .from("notes_purchase")
    .select("id")
    .eq("user_id", userId)
    .eq("note_id", numericId)
    .maybeSingle();

  if (existsErr) throw existsErr;
  if (exists) return { alreadyPurchased: true };

  // 2) Get price
  const { data: noteRow, error: priceErr } = await supabase
    .from("notes")
    .select("price")
    .eq("id", numericId)
    .single();

  if (priceErr) throw priceErr;

  const price = Number(noteRow?.price) || 0;

  // 🚫 Paid book without payment → block
if (price > 0 && !paymentId) {
  throw new Error("Payment required for paid note");
}

  // 3) Insert into notes_purchase
  // notes_purchase.id is likely bigint/uuid with DEFAULT -> don't send id
  const { error } = await supabase.from("notes_purchase").insert({
    user_id: userId,
    note_id: numericId,
    purchased_at: new Date().toISOString(),
  });

  if (error) throw error;

  // 4) Insert revenue: use old_item_id (integer), item_id = null
  const { error: revErr } = await supabase.from("revenue").insert({
    user_id: userId,
    amount: price,
    item_type: "note",
    item_id: null,          // avoid uuid error
    old_item_id: numericId, // integer
    created_at: new Date().toISOString(),
   payment_id: payment?.payment_id || null

  });

  if (revErr) {
    console.error("Revenue insert failed (note):", revErr.message);
  }

  return { success: true };
}

/* ============================================================
   4️⃣ CHECK PURCHASE STATUS
=============================================================== */
export const checkPurchase = async (req, res) => {
  try {
    const userId = req.user.id;


    const { bookId, noteId } = req.query;

    if (!userId || !isUUID(userId)) {
      return res.status(400).json({ error: "Invalid user id" });
    }

    if (!bookId && !noteId) {
      return res.status(400).json({ error: "Missing bookId or noteId" });
    }

    // Book purchase check
    if (bookId) {
      if (!isUUID(bookId)) {
        return res.status(400).json({ error: "Invalid bookId format" });
      }

      const { data, error } = await supabase
        .from("book_sales")
        .select("id")
        .eq("user_id", userId)
        .eq("book_id", bookId)
        .maybeSingle();

      if (error) {
        console.error("checkPurchase book error:", error.message);
        return res.status(500).json({ error: "Database error" });
      }

      return res.json({ purchased: !!data });
    }

    // Note purchase check
    if (noteId) {
      const numericId = Number(noteId);
      if (!numericId) {
        return res.status(400).json({ error: "Invalid noteId format" });
      }

      const { data, error } = await supabase
        .from("notes_purchase")
        .select("id")
        .eq("user_id", userId)
        .eq("note_id", numericId)
        .maybeSingle();

      if (error) {
        console.error("checkPurchase note error:", error.message);
        return res.status(500).json({ error: "Database error" });
      }

      return res.json({ purchased: !!data });
    }
  } catch (err) {
    console.error("checkPurchase error:", err.message || err);
    return res.status(500).json({ error: "Error checking purchase" });
  }
};

/* ============================================================
   5️⃣ GET PURCHASED BOOKS
=============================================================== */
export const getPurchasedBooks = async (req, res) => {
  try {
    const userId = req.user.id;



    if (!userId || !isUUID(userId)) {
      return res.status(400).json({ error: "Invalid user id" });
    }

    const { data, error } = await supabase
      .from("book_sales")
      .select(
        `
        id,
        book_id,
        purchased_at,
        books (*)
      `
      )
      .eq("user_id", userId);

    if (error) throw error;

    const books =
      data?.map((row) => ({
        ...row.books,
        purchased_at: row.purchased_at,
      })) || [];

    return res.json(books);
  } catch (err) {
    console.error("getPurchasedBooks error:", err.message || err);
    return res.status(500).json({ error: "Failed to get purchased books" });
  }
};

/* ============================================================
   6️⃣ GET PURCHASED BOOK IDS
=============================================================== */
export const getPurchasedBookIds = async (req, res) => {
  try {
   const userId = req.user.id;


    if (!userId || !isUUID(userId)) {
      return res.status(400).json({ error: "Invalid user id" });
    }

    const { data, error } = await supabase
      .from("book_sales")
      .select("book_id")
      .eq("user_id", userId);

    if (error) throw error;

    return res.json(data.map((row) => row.book_id));
  } catch (err) {
    console.error("getPurchasedBookIds error:", err.message || err);
    return res.status(500).json([]);
  }
};

/* ============================================================
   7️⃣ GET PURCHASED NOTE IDS
=============================================================== */
export const getPurchasedNoteIds = async (req, res) => {
  try {
    const userId = req.user.id;



    if (!userId || !isUUID(userId)) {
      return res.status(400).json({ error: "Invalid user id" });
    }

    const { data, error } = await supabase
      .from("notes_purchase")
      .select("note_id")
      .eq("user_id", userId);

    if (error) throw error;

    return res.json(data.map((row) => Number(row.note_id)));
  } catch (err) {
    console.error("getPurchasedNoteIds error:", err.message || err);
    return res.status(500).json([]);
  }
};
