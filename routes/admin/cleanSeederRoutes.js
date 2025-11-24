import express from "express";
import { supabaseAdmin } from "../../utils/supabaseClient.js";

const router = express.Router();

router.delete("/delete-all-fake-auth-users", async (req, res) => {
  try {
    const KEEP = [
      "harith@gmail.com",
      "superadmin@gmail.com",
      "alan@gmail.com"
    ];

    const { data, error } = await supabaseAdmin.auth.admin.listUsers();

    if (error) return res.status(500).json({ error: error.message });

    const users = data.users;

    let deleteCount = 0;

    for (const u of users) {
      const safe = u.email && KEEP.includes(u.email);

      if (!safe) {
        const { error: delErr } = await supabaseAdmin.auth.admin.deleteUser(u.id);

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
