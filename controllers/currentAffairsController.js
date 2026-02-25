import { supabaseAdmin } from "../utils/supabaseClient.js";
import pool from "../utils/db.js";

/* ----------------------------------
   GET CURRENT AFFAIRS (USER)
---------------------------------- */
export const getCurrentAffairs = async (req, res) => {
  try {
    const userId = req.user.id;
    const { category = "all", search = "", page = 1, limit = 9 } = req.query;

    const from = (page - 1) * limit;
    const to = from + Number(limit) - 1;




    let query = supabaseAdmin
      .from("current_affairs")
      .select(
        "id,title,category,content,tags,importance,views,article_date,article_time,image_url",
        { count: "exact" }
      )
      .eq("status", "published")
      .order("article_date", { ascending: false })
      .range(from, to);

    if (category !== "all") {
  query = query.eq("category", category);
}


   if (search) {
  const safeSearch = search.toLowerCase();

  query = query.or(
    `title.ilike.%${safeSearch}%,content.ilike.%${safeSearch}%,tags.ilike.%${safeSearch}%`
  );
}

    const { data, error, count } = await query;
    if (error) throw error;

    const safeData = Array.isArray(data) ? data : [];

    // Increment views for each article (once per user, silently)
    await Promise.all(
      safeData.map(article =>
        pool.query(
          `INSERT INTO current_affairs_views (article_id, user_id)
           VALUES ($1, $2)
           ON CONFLICT (article_id, user_id) DO NOTHING`,
          [article.id, userId]
        ).then(() =>
          pool.query(
            `UPDATE current_affairs SET views = (
               SELECT COUNT(*) FROM current_affairs_views WHERE article_id = $1
             ) WHERE id = $1`,
            [article.id]
          )
        ).catch(e => console.warn("View increment skipped:", e.message))
      )
    );

    res.json({
      page: Number(page),
      limit: Number(limit),
      total: count ?? 0,
      data: safeData.map(a => ({
        id: a.id,
        title: a.title,
        category: a.category,
        description: a.content,
        tags: a.tags
  ? a.tags.split(",").map(t => t.trim().toLowerCase())
  : [],

        importance: a.importance,
        views: a.views ?? 0,
        date: a.article_date,
        time: a.article_time,
        image_url: a.image_url,
      })),
    });
  } catch (err) {
    console.error("CURRENT AFFAIRS ERROR:", err);
    res.status(500).json({ error: "Failed to load current affairs" });
  }
};



/* ----------------------------------
   INCREMENT VIEW COUNT
---------------------------------- */
export const incrementViews = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user.id; // from auth middleware

    // Insert view record (once per user) and update count
    await pool.query(
      `INSERT INTO current_affairs_views (article_id, user_id)
       VALUES ($1, $2)
       ON CONFLICT (article_id, user_id) DO NOTHING`,
      [id, userId]
    );
    await pool.query(
      `UPDATE current_affairs SET views = (
         SELECT COUNT(*) FROM current_affairs_views WHERE article_id = $1
       ) WHERE id = $1`,
      [id]
    );

    res.json({ success: true });
  } catch (err) {
    console.error("VIEW UPDATE ERROR:", err);
    res.status(500).json({ error: "Failed to update views" });
  }
};
export const getCurrentAffairsCategories = async (req, res) => {
  try {
    const { data, error } = await supabaseAdmin
      .from("current_affairs")
      .select("category")
      .eq("status", "published");

    if (error) throw error;

    const uniqueCategories = [
      "all",
      ...Array.from(
        new Set(data.map(item => item.category?.toLowerCase()))
      ).filter(Boolean)
    ];

    res.json(
      uniqueCategories.map(cat => ({
        id: cat,
        name: cat === "all"
          ? "All Categories"
          : cat.charAt(0).toUpperCase() + cat.slice(1),
      }))
    );

  } catch (err) {
    console.error("CATEGORY FETCH ERROR:", err);
    res.status(500).json({ error: "Failed to load categories" });
  }
};
