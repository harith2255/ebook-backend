// src/controllers/folderController.js
import { supabaseAdmin } from "../utils/supabaseClient.js";

export async function listFolders(req, res) {
  try {
    const { data, error } = await supabaseAdmin
      .from("folders")
      .select("*")
      .order("name", { ascending: true });
    if (error) throw error;
    return res.json({ success: true, folders: data });
  } catch (err) {
    console.error("listFolders:", err);
    return res.status(500).json({ error: err.message || err });
  }
}
