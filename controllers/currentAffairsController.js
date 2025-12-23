import { supabaseAdmin } from "../utils/supabaseClient.js";

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

    await Promise.all(
      safeData.map(article =>
        supabaseAdmin.rpc("increment_current_affairs_views_once", {
          p_article_id: article.id,
          p_user_id: userId,
        })
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

    const { error } = await supabaseAdmin.rpc(
      "increment_current_affairs_views_once",
      {
        p_article_id: id,
        p_user_id: userId,
      }
    );

    if (error) throw error;

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
