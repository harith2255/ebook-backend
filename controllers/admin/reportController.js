// controllers/admin/reportsController.js
import supabase from "../../utils/supabaseClient.js";

/* -------------------------------------------------------
   Helper: Month Names
------------------------------------------------------- */
const MONTHS = [
  "Jan", "Feb", "Mar", "Apr", "May", "Jun",
  "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
];

/* -------------------------------------------------------
   1. GET ANALYTICS (Revenue + Users + Books)
------------------------------------------------------- */
export const getAnalytics = async (req, res) => {
  try {
    /* ---------------- Revenue ------------------ */
    const { data: subscriptions, error: subErr } = await supabase
      .from("subscriptions")
      .select("amount, created_at");

    if (subErr) return res.status(400).json({ error: subErr.message });


    /* ---------------- Book Sales ---------------- */
    const { data: bookSales, error: bookErr } = await supabase
      .from("book_sales")
      .select("created_at");

    if (bookErr) return res.status(400).json({ error: bookErr.message });


    /* ---------------- Users (auth) -------------- */
    const { data: authUsers, error: userErr } =
      await supabase.auth.admin.listUsers();

    if (userErr) return res.status(400).json({ error: userErr.message });

    const allUsers = authUsers?.users || [];


    /* ------------------------------------------------
       Build analytics for ALL 12 months
    ------------------------------------------------ */
    const analytics = MONTHS.map((m, i) => {
      const revenue = subscriptions
        ?.filter(s => new Date(s.created_at).getMonth() === i)
        .reduce((sum, row) => sum + Number(row.amount), 0);

      const users = allUsers
        .filter(u => new Date(u.created_at).getMonth() === i).length;

      const books = bookSales
        ?.filter(b => new Date(b.created_at).getMonth() === i).length;

      return {
        month: m,
        revenue,
        users,
        books,
      };
    });

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
    const { data, error } = await supabase
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
   3. Generate CSV Report and Upload to Storage
------------------------------------------------------- */
/* -------------------------------------------------------
   3. Generate Analytics CSV (Revenue + Users + Books)
------------------------------------------------------- */
export const generateReport = async (req, res) => {
  try {
    const MONTHS = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];

    /* ---------------- Revenue (subscriptions) ---------------- */
    const { data: subscriptions, error: subErr } = await supabase
      .from("subscriptions")
      .select("amount, created_at");

    if (subErr) return res.status(400).json({ error: subErr.message });

    /* ---------------- Books Sold ---------------- */
    const { data: bookSales, error: bookErr } = await supabase
      .from("book_sales")
      .select("created_at");

    if (bookErr) return res.status(400).json({ error: bookErr.message });

    /* ---------------- Users (auth) ---------------- */
    const { data: authUsers, error: userErr } =
      await supabase.auth.admin.listUsers();

    if (userErr) return res.status(400).json({ error: userErr.message });

    const allUsers = authUsers?.users || [];


    /* -------------------------------------------------------
       Build Analytics for ALL 12 months
    ------------------------------------------------------- */
    const analytics = MONTHS.map((m, i) => {
      const revenue = subscriptions
        ?.filter(s => new Date(s.created_at).getMonth() === i)
        .reduce((sum, row) => sum + Number(row.amount), 0);

      const users = allUsers
        ?.filter(u => new Date(u.created_at).getMonth() === i).length;

      const books = bookSales
        ?.filter(b => new Date(b.created_at).getMonth() === i).length;

      return { month: m, revenue, users, books };
    });


    /* -------------------------------------------------------
       Convert to CSV
    ------------------------------------------------------- */
    const csvHeader = "month,revenue,users,books\n";
    const csvRows = analytics.map(a =>
      `${a.month},${a.revenue},${a.users},${a.books}`
    );

    const csv = csvHeader + csvRows.join("\n");


    /* -------------------------------------------------------
       Upload CSV to Supabase Storage
    ------------------------------------------------------- */
    const fileName = `analytics-${Date.now()}.csv`;

    const { error: uploadErr } = await supabase.storage
      .from("reports")
      .upload(fileName, csv, {
        contentType: "text/csv",
        upsert: true,
      });

    if (uploadErr) return res.status(400).json({ error: uploadErr.message });

    const { data: urlData } = supabase.storage
      .from("reports")
      .getPublicUrl(fileName);


    /* -------------------------------------------------------
       Save metadata in "reports" table
    ------------------------------------------------------- */
    await supabase.from("reports").insert([
      {
        name: "Platform Analytics Report",
        description: "Revenue, user growth, and books sold (12 months)",
        format: "CSV",
        file_url: urlData.publicUrl
      }
    ]);


    /* -------------------------------------------------------
       Response
    ------------------------------------------------------- */
    res.json({
      message: "Analytics report generated successfully",
      url: urlData.publicUrl,
    });

  } catch (err) {
    console.error("🔥 generateReport error:", err);
    res.status(500).json({ error: "Failed to generate report" });
  }
};



/* -------------------------------------------------------
   4. Download Specific Report (redirect)
------------------------------------------------------- */
export const downloadReport = async (req, res) => {
  try {
    const { id } = req.params;

    const { data, error } = await supabase
      .from("reports")
      .select("file_url")
      .eq("id", id)
      .single();

    if (error || !data) {
      return res.status(404).json({ error: "Report not found" });
    }

   const response = await fetch(data.file_url);
const buffer = await response.arrayBuffer();
res.setHeader("Content-Type", "text/csv");
res.send(Buffer.from(buffer));

  } catch (err) {
    console.error("🔥 downloadReport error:", err);
    res.status(500).json({ error: "Failed to download report" });
  }
};
