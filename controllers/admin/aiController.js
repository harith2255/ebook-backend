import supabase from "../../utils/supabaseClient.js";
import {
  aiAutoTags,
  aiSummary,
  embedText,
  checkPlagiarism,
  semanticSearchEmbed,
  averageEmbeddings
} from "../../utils/aiHelper.js";

/* ----------------------------------------------------
 ✅ GET AI SETTINGS
---------------------------------------------------- */
export const getAISettings = async (req, res) => {
  const { data, error } = await supabase.from("ai_settings").select("*").single();
  if (error) return res.status(400).json({ error: error.message });

  res.json({ settings: data });
};

/* ----------------------------------------------------
 ✅ UPDATE AI SETTINGS
---------------------------------------------------- */
export const updateAISettings = async (req, res) => {
  const updates = req.body;

  const { data, error } = await supabase
    .from("ai_settings")
    .update({ ...updates, updated_at: new Date() })
    .eq("id", updates.id)
    .select()
    .single();

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: "AI settings updated", settings: data });
};

/* ----------------------------------------------------
 ✅ PROCESS CONTENT (AUTO-TAGGING + SUMMARY + EMBEDDING + PLAGIARISM)
---------------------------------------------------- */
export const processContentAI = async (req, res) => {
  try {
    const { id, type } = req.params;

    const table =
      type === "ebook" ? "ebooks" :
      type === "note"  ? "notes"  :
      null;

    if (!table) return res.status(400).json({ error: "Invalid type" });

    // Load settings
    const { data: settings } = await supabase.from("ai_settings").select("*").single();

    // Get content
    const { data: content, error } = await supabase
      .from(table)
      .select("title, description")
      .eq("id", id)
      .single();

    if (error || !content) return res.status(404).json({ error: "Content not found" });

    const text = `${content.title}\n${content.description || ""}`;

    let tags = [];
    let summary = "";
    let embedding = null;
    let plagiarism = null;
    let plagiarism_detected = false;

    // ✅ Auto Tagging
    if (settings.auto_tagging) {
      tags = await aiAutoTags(text);
    }

    // ✅ Summary
    if (settings.summary_generation) {
      summary = await aiSummary(text);
    }

    // ✅ Embedding
    embedding = await embedText(text);

    // ✅ Plagiarism Check
    if (settings.plagiarism_detection) {
      plagiarism = await checkPlagiarism(embedding, 0.90);
      plagiarism_detected =
        plagiarism.ebooks.length > 0 || plagiarism.notes.length > 0;
    }

    // ✅ Update content in DB
    await supabase
      .from(table)
      .update({
        tags,
        summary,
        embedding,
        plagiarism_detected,
        plagiarism_matches: plagiarism
      })
      .eq("id", id);

    // ✅ Log activity
    await supabase.from("ai_activity_log").insert([
      {
        action: `AI Processed ${type}: ${content.title}`,
        status: plagiarism_detected ? "Plagiarism Detected" : "Completed",
        details: JSON.stringify({ tags, summary, plagiarism })
      }
    ]);

    res.json({
      message: "AI processing complete",
      tags,
      summary,
      plagiarism,
      plagiarism_detected
    });

  } catch (err) {
    console.error("processContentAI error:", err);
    res.status(500).json({ error: "AI processing failed" });
  }
};

/* ----------------------------------------------------
 ✅ AI ACTIVITY LOGS
---------------------------------------------------- */
export const getAILogs = async (req, res) => {
  const { data, error } = await supabase
    .from("ai_activity_log")
    .select("*")
    .order("created_at", { ascending: false });

  if (error) return res.status(400).json({ error: error.message });

  res.json({ logs: data });
};

/* ----------------------------------------------------
 ✅ SEMANTIC SEARCH ENDPOINT
---------------------------------------------------- */
export const semanticSearch = async (req, res) => {
  try {
    const { query } = req.query;
    if (!query) return res.status(400).json({ error: "Query required" });

    const embedding = await semanticSearchEmbed(query);

    const { data: ebooks } = await supabase.rpc("match_ebooks", {
      query_embedding: embedding,
      similarity_threshold: 0.50,
      match_count: 10
    });

    const { data: notes } = await supabase.rpc("match_notes", {
      query_embedding: embedding,
      similarity_threshold: 0.50,
      match_count: 10
    });

    res.json({ results: [...ebooks, ...notes] });

  } catch (err) {
    console.error("semanticSearch error:", err);
    res.status(500).json({ error: "Semantic search failed" });
  }
};

/* ----------------------------------------------------
 ✅ BOOK RECOMMENDATIONS BASED ON USER INTERESTS
---------------------------------------------------- */
export const recommendBooks = async (req, res) => {
  try {
    const userId = req.user.id;

    const { data: views } = await supabase
      .from("book_views")
      .select("book_id")
      .eq("user_id", userId);

    if (!views || views.length === 0)
      return res.json({ recommendations: [] });

    const bookIds = views.map(v => v.book_id);

    const { data: books } = await supabase
      .from("ebooks")
      .select("id, title, embedding")
      .in("id", bookIds);

    const embeddings = books.map(b => b.embedding);

    const userEmbedding = averageEmbeddings(embeddings);

    const { data: recs } = await supabase.rpc("match_ebooks", {
      query_embedding: userEmbedding,
      similarity_threshold: 0.50,
      match_count: 10
    });

    res.json({ recommendations: recs });

  } catch (err) {
    console.error("recommendBooks error:", err);
    res.status(500).json({ error: "Recommender failed" });
  }
};
