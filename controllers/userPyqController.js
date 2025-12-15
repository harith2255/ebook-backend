import { supabaseAdmin } from "../utils/supabaseClient.js";

/* --------------------------------
   GET SUBJECTS (LEVEL 1)
-------------------------------- */
export const getSubjects = async (req, res) => {
  try {
    const { data, error } = await supabaseAdmin
      .from("pyq_subjects")
      .select("id, name")
      .order("name");

    if (error) throw error;
    res.json(data);
  } catch {
    res.status(500).json({ error: "Failed to load subjects" });
  }
};

/* --------------------------------
   GET YEAR FOLDERS (LEVEL 2)
-------------------------------- */
export const getYearFolders = async (req, res) => {
  try {
    const { subjectId } = req.params;

    const { data, error } = await supabaseAdmin
      .from("pyq_papers")
      .select("year")
      .eq("subject_id", subjectId);

    if (error) throw error;

    const years = [...new Set(data.map(d => d.year))].sort((a, b) => a - b);

    if (!years.length) return res.json([]);

    const folders = [];
    let start = years[0];

    for (let i = 1; i <= years.length; i++) {
      if (years[i] !== years[i - 1] + 1) {
        folders.push({
          id: `${start}-${years[i - 1]}`,
          name: `${start}-${years[i - 1]}`,
          start,
          end: years[i - 1],
        });
        start = years[i];
      }
    }

    res.json(folders);
  } catch {
    res.status(500).json({ error: "Failed to load year folders" });
  }
};

/* --------------------------------
   GET PAPERS (LEVEL 3)
-------------------------------- */
export const getPapers = async (req, res) => {
  try {
    const { subjectId, start, end } = req.params;

    const { data, error } = await supabaseAdmin
      .from("pyq_papers")
      .select("id, type, title, year, file_url, file_size")
      .eq("subject_id", subjectId)
      .gte("year", start)
      .lte("year", end)
      .order("year");

    if (error) throw error;
    res.json(data);
  } catch {
    res.status(500).json({ error: "Failed to load papers" });
  }
};
