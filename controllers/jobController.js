import supabase from "../utils/supabaseClient.js";


// ✅ Get All Jobs
export const getAllJobs = async (req, res) => {
  const { data, error } = await supabase
    .from("jobs")
    .select("*")
    .order("created_at", { ascending: false });

  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
};


// ✅ Filter + Search Jobs
export const getFilteredJobs = async (req, res) => {
  const { search = "", type = "all", level = "all" } = req.query;

  let query = supabase.from("jobs").select("*");

  if (search) {
    query = query.ilike("title", `%${search}%`)
      .or(`company.ilike.%${search}%,description.ilike.%${search}%`);
  }

  if (type !== "all") query = query.eq("type", type);
  if (level !== "all") query = query.eq("level", level);

  const { data, error } = await query;

  if (error) return res.status(400).json({ error: error.message });
  res.json(data);
};


// ✅ Admin: Create Job
export const createJob = async (req, res) => {
  const body = req.body;

  const { data, error } = await supabase
    .from("jobs")
    .insert([body])
    .select();

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: "Job created", job: data[0] });
};


// ✅ Admin: Update Job
export const updateJob = async (req, res) => {
  const jobId = req.params.id;

  const { data, error } = await supabase
    .from("jobs")
    .update(req.body)
    .eq("id", jobId)
    .select();

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: "Job updated", job: data[0] });
};


// ✅ Admin: Delete Job
export const deleteJob = async (req, res) => {
  const jobId = req.params.id;

  const { error } = await supabase
    .from("jobs")
    .delete()
    .eq("id", jobId);

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: "Job deleted successfully" });
};


// ✅ Save Job for User
export const saveJob = async (req, res) => {
  const userId = req.user.id;
  const { job_id } = req.body;

  const { data, error } = await supabase
    .from("saved_jobs")
    .insert([{ user_id: userId, job_id }])
    .select();

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: "Job saved", saved: data[0] });
};


// ✅ Get User Saved Jobs
export const getSavedJobs = async (req, res) => {
  const userId = req.user.id;

  const { data, error } = await supabase
    .from("saved_jobs")
    .select("*, jobs(*)")
    .eq("user_id", userId);

  if (error) return res.status(400).json({ error: error.message });

  res.json(data);
};


// ✅ Apply to Job
export const applyToJob = async (req, res) => {
  const userId = req.user.id;
  const { job_id } = req.body;

  // Store application in the applications table (create if needed)
  const { data, error } = await supabase
    .from("job_applications")
    .insert([{ user_id: userId, job_id }]);

  if (error) return res.status(400).json({ error: error.message });

  res.json({ message: "Applied successfully!" });
};
