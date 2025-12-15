import { supabaseAdmin } from "../utils/supabaseClient.js";

/* ----------------------------------
   GET CURRENT AFFAIRS (USER)
---------------------------------- */
export const getCurrentAffairs = async (req, res) => {
  try {
    const {
      category = "all",
      search = "",
      page = 1,
      limit = 9,
    } = req.query;

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
      query = query.or(
        `title.ilike.%${search}%,content.ilike.%${search}%`
      );
    }

    const { data, error, count } = await query;
    const CATEGORY_MAP = {
  "National Affairs": "national",
  "International News": "international",
  "Economy": "economy",
  "Science & Tech": "science",
  "Sports": "sports",
  "Environment": "environment",
};


    if (error) throw error;

    const safeData = Array.isArray(data) ? data : [];

   const formatted = safeData.map(a => ({
  id: a.id,
  title: a.title,
  category: CATEGORY_MAP[a.category] || "other",
  description: a.content,
  tags: a.tags ? a.tags.split(",") : [],
  importance: a.importance,
  views: a.views ?? 0,
  date: a.article_date,
  time: a.article_time,
  image_url: a.image_url,
}));


    res.json({
      page: Number(page),
      limit: Number(limit),
      total: count ?? 0,
      data: formatted,
    });
  } catch (err) {
    console.error("GET CURRENT AFFAIRS ERROR:", err);
    res.status(500).json({
      error: "Failed to load current affairs",
    });
  }
};


/* ----------------------------------
   INCREMENT VIEW COUNT
---------------------------------- */
export const incrementViews = async (req, res) => {
  try {
    const { id } = req.params;

    const { error } = await supabaseAdmin.rpc(
      "increment_current_affairs_views",
      { row_id: id }
    );

    if (error) throw error;

    res.json({ message: "View count updated" });
  } catch (err) {
    res.status(500).json({ error: "Failed to update views" });
  }
};
