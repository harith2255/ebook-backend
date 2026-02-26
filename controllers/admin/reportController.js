// controllers/admin/reportsController.js
import { supabaseAdmin } from "../../utils/pgClient.js";
import fs from "fs";
import path from "path";

/* -------------------------------------------------------
   Helper: Month Names
------------------------------------------------------- */
const MONTHS = [
  "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
];

// Build last 12 months with labels + keys
function buildLast12Months() {
  const now = new Date();
  const months = [];

  for (let i = 11; i >= 0; i--) {
    const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
    const key = `${d.getFullYear()}-${d.getMonth()}`; // e.g. "2025-11"
    const label = `${MONTHS[d.getMonth()]} ${String(d.getFullYear()).slice(-2)}`; // "Dec 25"

    months.push({
      key,
      label,
      year: d.getFullYear(),
      monthIndex: d.getMonth(),
      revenue: 0,
      users: 0,
      books: 0,
    });
  }

  return months;
}

/* -------------------------------------------------------
   1. GET ANALYTICS (Revenue + Users + Books)
------------------------------------------------------- */
export const getAnalytics = async (req, res) => {
  try {
    const months = buildLast12Months();
    const monthMap = new Map(months.map(m => [m.key, m]));

    const oldest = months[0];
    const oldestDate = new Date(oldest.year, oldest.monthIndex, 1);

    /* ---------------- Revenue (from revenue table) ---------------- */
    const { data: revenueRows, error: revErr } = await supabaseAdmin
      .from("revenue")
      .select("amount, created_at, item_type", { head: false })

      .gte("created_at", oldestDate.toISOString());

    if (revErr) return res.status(400).json({ error: revErr.message });

    // Aggregate revenue + books sold
    revenueRows?.forEach(row => {
      const d = new Date(row.created_at);
      const key = `${d.getFullYear()}-${d.getMonth()}`;
      const bucket = monthMap.get(key);
      if (!bucket) return;

      const amount = Number(row.amount || 0);
      bucket.revenue += amount;

      if (row.item_type === "book") {
        bucket.books += 1;
      }
    });

    /* ---------------- Users (from v_customers) ---------------- */
    const { data: usersRows, error: userErr } = await supabaseAdmin
      .from("v_customers")
     .select("created_at")

      .gte("created_at", oldestDate.toISOString());

    if (userErr) return res.status(400).json({ error: userErr.message });

    usersRows?.forEach(u => {
      const d = new Date(u.created_at);
      const key = `${d.getFullYear()}-${d.getMonth()}`;
      const bucket = monthMap.get(key);
      if (!bucket) return;
      bucket.users += 1;
    });

    // Convert to frontend shape
    const analytics = months.map(m => ({
      month: m.label,        // "Dec 25"
      revenue: m.revenue,    // number
      users: m.users,        // number
      books: m.books,        // number
    }));

    return res.json({ analytics });

  } catch (err) {
    console.error("🔥 getAnalytics error:", err);
    res.status(500).json({ error: "Failed to load analytics" });
  }
};


/* -------------------------------------------------------
   2. List Previously Generated Reports
------------------------------------------------------- */
export const getReports = async (req, res) => {
  try {
    const { data, error } = await supabaseAdmin
      .from("reports")
      .select("*")
      .order("created_at", { ascending: false });

    if (error) return res.status(400).json({ error: error.message });

    res.json({ reports: data });
  } catch (err) {
    console.error("🔥 getReports error:", err);
    res.status(500).json({ error: "Failed to load reports" });
  }
};


/* -------------------------------------------------------
   3. Generate Analytics CSV (Revenue + Users + Books)
------------------------------------------------------- */
export const generateReport = async (req, res) => {
  try {
    const months = buildLast12Months();
    const monthMap = new Map(months.map((m) => [m.key, m]));

    const oldest = months[0];
    const oldestDate = new Date(oldest.year, oldest.monthIndex, 1);

    /* ---------------- Revenue (from revenue) ---------------- */
    const { data: revenueRows, error: revErr } = await supabaseAdmin
      .from("revenue")
      .select("amount, created_at, item_type")
      .gte("created_at", oldestDate.toISOString());

    if (revErr)
      return res.status(400).json({ error: revErr.message });

    revenueRows?.forEach((row) => {
      const d = new Date(row.created_at);
      const key = `${d.getFullYear()}-${d.getMonth()}`;
      const bucket = monthMap.get(key);
      if (!bucket) return;

      bucket.revenue += Number(row.amount || 0);

      if (row.item_type === "book") bucket.books++;
    });

    /* ---------------- Users (from v_customers) ---------------- */
    const { data: usersRows, error: userErr } = await supabaseAdmin
      .from("v_customers")
      .select("id, created_at")
      .gte("created_at", oldestDate.toISOString());

    if (userErr)
      return res.status(400).json({ error: userErr.message });

    usersRows?.forEach((u) => {
      const d = new Date(u.created_at);
      const key = `${d.getFullYear()}-${d.getMonth()}`;
      const bucket = monthMap.get(key);
      if (!bucket) return;
      bucket.users++;
    });

    /* -------------------------------------------------------
       Build result data
    ------------------------------------------------------- */
    const analytics = months.map((m) => ({
      month: m.label,
      revenue: m.revenue,
      users: m.users,
      books: m.books,
    }));

    /* -------------------------------------------------------
       Convert to CSV
    ------------------------------------------------------- */
    const csvHeader = "month,revenue,users,books\n";
    const csvRows = analytics.map(
      (a) => `${a.month},${a.revenue},${a.users},${a.books}`
    );
    const csv = csvHeader + csvRows.join("\n");

    /* -------------------------------------------------------
       Upload CSV to Local Storage  (Buffer!)
    ------------------------------------------------------- */
    const fileName = `analytics-${Date.now()}.csv`;
    const buffer = Buffer.from(csv, "utf-8");
    
    const reportsDir = path.join(process.cwd(), "uploads", "reports");
    if (!fs.existsSync(reportsDir)) {
      fs.mkdirSync(reportsDir, { recursive: true });
    }
    
    const filePath = path.join(reportsDir, fileName);
    await fs.promises.writeFile(filePath, buffer);

    /* -------------------------------------------------------
       Get public URL
    ------------------------------------------------------- */
    const publicURL = `${process.env.BACKEND_URL || "http://localhost:5000"}/uploads/reports/${fileName}`;

    /* -------------------------------------------------------
       Save metadata in "reports" table
    ------------------------------------------------------- */
    await supabaseAdmin.from("reports").insert([
      {
        name: "Platform Analytics Report",
        description: "Revenue, user growth, and books sold (last 12 months)",
        format: "CSV",
        file_url: publicURL,
      },
    ]);

    /* -------------------------------------------------------
       Response
    ------------------------------------------------------- */
    return res.json({
      message: "Analytics report generated successfully",
      url: publicURL,
    });
  } catch (err) {
    console.error("🔥 generateReport error:", err);
    return res.status(500).json({
      error: err.message || "Internal server error",
    });
  }
};


/* -------------------------------------------------------
   4. Download Specific Report (redirect)
------------------------------------------------------- */
export const downloadReport = async (req, res) => {
  try {
    const { id } = req.params;

    const { data, error } = await supabaseAdmin
      .from("reports")
      .select("file_url")
      .eq("id", id)
      .single();

    if (error || !data) {
      return res.status(404).json({ error: "Report not found" });
    }

    // data.file_url is like http://localhost:5000/uploads/reports/analytics-123.csv
    const fileName = data.file_url.split("/").pop();
    const filePath = path.join(process.cwd(), "uploads", "reports", fileName);

    if (!fs.existsSync(filePath)) {
       return res.status(404).json({ error: "Report file missing on server" });
    }

    res.download(filePath, fileName, (err) => {
      if (err) {
        console.error("Download error:", err);
      }
    });
  } catch (err) {
    console.error("🔥 downloadReport error:", err);
    res.status(500).json({ error: "Failed to download report" });
  }
};
