import express from "express";
import supabase from "../../utils/pgClient.js";

const router = express.Router();

router.delete("/delete-all-fake-auth-users", async (req, res) => {
  try {
    const KEEP = [
      "harith@gmail.com",
      "superadmin@gmail.com",
      "alan@gmail.com"
    ];

    // List all profiles from DB
    const { data: users, error } = await supabase
      .from("profiles")
      .select("id, email");

    if (error) return res.status(500).json({ error: error.message });

    let deleteCount = 0;

    for (const u of (users || [])) {
      const safe = u.email && KEEP.includes(u.email);

      if (!safe) {
        const { error: delErr } = await supabase
          .from("profiles")
          .delete()
          .eq("id", u.id);

        if (!delErr) {
          deleteCount++;
          console.log("Deleted:", u.email || "(no email)", u.id);
        }
      }
    }

    return res.json({
      message: "Cleanup completed",
      deleted: deleteCount
    });

  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});


export default router;
