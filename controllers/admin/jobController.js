import supabase from "../../utils/pgClient.js";

/* -------------------------------------------------
 ✅ Get all jobs with requirements
------------------------------------------------- */
export const getJobs = async (req, res) => {
  try {
    const { data: jobs } = await supabase
      .from("jobs")
      .select("*")
      .order("id", { ascending: false });

    const { data: reqs } = await supabase
      .from("job_requirements")
      .select("*");

    // Attach requirements to each job
    const merged = jobs.map(job => ({
      ...job,
      requirements: reqs
        .filter(r => r.job_id === job.id)
        .map(r => r.requirement)
    }));

    res.json({ jobs: merged });

  } catch (err) {
    console.error("getJobs error:", err);
    res.status(500).json({ error: "Failed to load jobs" });
  }
};

/* -------------------------------------------------
 ✅ Create a new job
------------------------------------------------- */
export const createJob = async (req, res) => {
  try {
    const { title, company, location, type, level, salary, description, requirements } = req.body;

    const { data: job, error } = await supabase
      .from("jobs")
      .insert([{ title, company, location, type, level, salary, description }])
      .select()
      .single();

    if (error) return res.status(400).json({ error: error.message });

    // Insert requirements
    if (requirements?.length) {
      const reqPayload = requirements.map(req => ({
        job_id: job.id,
        requirement: req
      }));

      await supabase.from("job_requirements").insert(reqPayload);
    }

    res.json({ message: "Job created", job });

  } catch (err) {
    console.error("createJob error:", err);
    res.status(500).json({ error: "Failed to create job" });
  }
};

/* -------------------------------------------------
 ✅ Update Job
------------------------------------------------- */
export const updateJob = async (req, res) => {
  try {
    const { id } = req.params;
    const { title, company, location, type, level, salary, description, requirements } = req.body;

    // Update job main fields
    const { error } = await supabase
      .from("jobs")
      .update({ title, company, location, type, level, salary, description })
      .eq("id", id);

    if (error) return res.status(400).json({ error: error.message });

    // Replace requirements
    await supabase.from("job_requirements").delete().eq("job_id", id);

    if (requirements?.length) {
      const reqPayload = requirements.map(req => ({
        job_id: Number(id),
        requirement: req
      }));
      await supabase.from("job_requirements").insert(reqPayload);
    }

    res.json({ message: "Job updated" });

  } catch (err) {
    console.error("updateJob error:", err);
    res.status(500).json({ error: "Failed to update job" });
  }
};

/* -------------------------------------------------
 ✅ Delete Job
------------------------------------------------- */
export const deleteJob = async (req, res) => {
  try {
    const { id } = req.params;

    await supabase.from("jobs").delete().eq("id", id);

    res.json({ message: "Job deleted" });
  } catch (err) {
    console.error("deleteJob error:", err);
    res.status(500).json({ error: "Failed to delete job" });
  }
};
