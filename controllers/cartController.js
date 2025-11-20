// controllers/cartController.js
import supabase from "../utils/supabaseClient.js";

/* ------------------------------------------------------------
   GET /api/cart
------------------------------------------------------------ */
export async function getCart(req, res) {
  try {
    const userId = req.user.id;

    const { data: rows, error: errRows } = await supabase
      .from("user_cart")
      .select("*")
      .eq("user_id", userId);

    if (errRows) return res.status(500).json({ error: errRows.message });

    const enriched = [];

    for (const r of rows ?? []) {

      /* ----------------------------------------------------
         📘 BOOK ITEM
      ---------------------------------------------------- */
      if (r.book_id) {
        const { data: book } = await supabase
          .from("ebooks")
          .select("id, title, author, price, pages, file_url, category")
          .eq("id", r.book_id)
          .maybeSingle();

        // ❌ Book not found → auto remove from cart
        if (!book) {
          await supabase.from("user_cart").delete().eq("id", r.id);
          continue;
        }

        enriched.push({ ...r, book });
      }

      /* ----------------------------------------------------
         📝 NOTE ITEM
      ---------------------------------------------------- */
      if (r.note_id) {
        const { data: note, error: errNote } = await supabase
          .from("notes")
          .select("*")
          .eq("id", r.note_id)
          .maybeSingle();

        // ❌ Note not found → auto remove
        if (!note) {
          await supabase.from("user_cart").delete().eq("id", r.id);
          continue;
        }

        enriched.push({ ...r, note });
      }
    }

    return res.json({ items: enriched });

  } catch (err) {
    console.error("Cart GET error:", err);
    return res.status(500).json({ error: err.message });
  }
}

/* ------------------------------------------------------------
   POST /api/cart/add
------------------------------------------------------------ */
export async function addToCart(req, res) {
  try {
    const userId = req.user.id;
    const { book_id, note_id, quantity = 1 } = req.body;

    if ((!book_id && !note_id) || (book_id && note_id)) {
      return res.status(400).json({
        error: "Provide exactly one of book_id or note_id",
      });
    }

    const matchCol = book_id ? { book_id } : { note_id };

    const { data: existing } = await supabase
      .from("user_cart")
      .select("id, quantity")
      .eq("user_id", userId)
      .match(matchCol)
      .maybeSingle();

    if (existing) {
      const newQty = (existing.quantity || 1) + quantity;

      const { data, error } = await supabase
        .from("user_cart")
        .update({ quantity: newQty })
        .eq("id", existing.id)
        .select()
        .single();

      if (error) throw error;
      return res.json({ success: true, data });
    }

    const { data, error } = await supabase
      .from("user_cart")
      .insert({
        user_id: userId,
        book_id: book_id || null,
        note_id: note_id || null,
        quantity,
      })
      .select()
      .single();

    if (error) throw error;

    return res.json({ success: true, data });

  } catch (err) {
    console.error("Cart ADD error:", err);
    return res.status(500).json({
      error: err.message || "Failed to add to cart",
    });
  }
}

/* ------------------------------------------------------------
   PATCH /api/cart/:id
------------------------------------------------------------ */
export async function updateCartQuantity(req, res) {
  try {
    const userId = req.user.id;
    const cartId = req.params.id;
    const { quantity } = req.body;

    if (!Number.isInteger(quantity) || quantity < 1) {
      return res
        .status(400)
        .json({ error: "Quantity must be an integer >= 1" });
    }

    const { data, error } = await supabase
      .from("user_cart")
      .update({ quantity })
      .eq("id", cartId)
      .eq("user_id", userId)
      .select()
      .single();

    if (error) throw error;

    return res.json({ success: true, data });

  } catch (err) {
    console.error("Cart PATCH error:", err);
    return res.status(500).json({
      error: err.message || "Failed to update cart",
    });
  }
}

/* ------------------------------------------------------------
   DELETE /api/cart/:id
------------------------------------------------------------ */
export async function removeCartItem(req, res) {
  try {
    const userId = req.user.id;
    const cartId = req.params.id;

    const { error } = await supabase
      .from("user_cart")
      .delete()
      .eq("id", cartId)
      .eq("user_id", userId);

    if (error) throw error;

    return res.json({ success: true });

  } catch (err) {
    console.error("Cart DELETE error:", err);
    return res.status(500).json({
      error: err.message || "Failed to remove cart item",
    });
  }
}
