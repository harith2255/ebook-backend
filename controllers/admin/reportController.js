// controllers/admin/reportsController.js
import supabase from "../../utils/supabaseClient.js";
import { createObjectCsvStringifier } from "csv-writer";
import fs from "fs";
import path from "path";


// ✅ 1. Revenue, User Growth, Books Sold
export const getAnalytics = async (req, res) => {
  try {
    // Revenue (Sum of all subscription payments)
    const { data: subscription } = await supabase
      .from("subscriptions")
      .select("amount, created_at");

    // User growth (auth.users)
    const { data: users } = await supabase.auth.admin.listUsers();
    const userList = users?.users || [];

    // Books sold (book_sales)
    const { data: bookSales } = await supabase
      .from("book_sales")
      .select("book_id, created_at");

    const months = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"];

    const analytics = months.map((m, i) => {
      const revenue = subscription
        ?.filter(s => new Date(s.created_at).getMonth() === i)
        .reduce((a, b) => a + Number(b.amount), 0);

      const newUsers = userList
        .filter(u => new Date(u.created_at).getMonth() === i).length;

      const books = bookSales
        ?.filter(s => new Date(s.created_at).getMonth() === i).length;

      return {
        month: m,
        revenue,
        users: newUsers,
        books
      };
    });

    res.json({ analytics });

  } catch (err) {
    console.error("getAnalytics error:", err);
    res.status(500).json({ error: "Failed to load analytics" });
  }
};


// ✅ 2. List Generated Reports
export const getReports = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from("reports")
      .select("*")
      .order("created_at", { ascending: false });

    if (error) return res.status(400).json({ error: error.message });

    res.json({ reports: data });
  } catch (err) {
    console.error("getReports error:", err);
    res.status(500).json({ error: "Failed to load reports" });
  }
};


// ✅ 3. Generate New Report (CSV)
export const generateReport = async (req, res) => {
  try {
    const { data: subscription } = await supabase.from("subscriptions").select("*");

    const csv = [
      "user_id,plan,amount,date",
      ...subscription.map(s => `${s.user_id},${s.plan},${s.amount},${s.created_at}`)
    ].join("\n");

    const fileName = `report-${Date.now()}.csv`;
    const filePath = fileName;


    // Upload to storage bucket
    const { error: upErr } = await supabase.storage
      .from("reports")
      .upload(filePath, Buffer.from(csv), {
        contentType: "text/csv"
      });

    if (upErr) return res.status(400).json({ error: upErr.message });

    const { data: urlData } = supabase.storage
      .from("reports")
      .getPublicUrl(filePath);

    // Insert record into DB
    await supabase.from("reports").insert([
      {
        name: "Monthly Revenue Report",
        description: "Generated revenue CSV",
        format: "CSV",
        file_url: urlData.publicUrl
      }
    ]);

    res.json({ message: "Report generated", url: urlData.publicUrl });

  } catch (err) {
    console.error("generateReport error:", err);
    res.status(500).json({ error: "Failed to generate report" });
  }
};


// ✅ 4. Download Specific Report
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

    // Redirect user to public URL
    res.redirect(data.file_url);

  } catch (err) {
    console.error("downloadReport error:", err);
    res.status(500).json({ error: "Failed to download report" });
  }
};
