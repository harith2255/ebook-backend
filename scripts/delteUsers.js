import { supabaseAdmin } from "../utils/supabaseClient.js";

// list of users remaining in Auth
const IDS = [
  "acd103fd-7adb-4bfa-9322-39d5682d5e4f",
  "c90f6497-45ff-4ca8-82ae-bd0029ece732",
  "cf877161-11d2-465f-baec-ef06f03c968e",
  "a76f5d56-c048-4cc8-9770-81b559ff1211",
  "82ed2690-d70c-4aeb-8dac-4f61f51961bb",
  "c7931e6d-1c4d-4ad0-919d-3283bde7b4ea",
  "33804e49-2fbe-4948-bdc4-866f83688311",
  "f23c5858-2e22-4e47-b5b5-d68d63028c25",
  "5d2a1aee-c221-43a5-93f5-2a746b6ecc37",
  "c0441710-197b-4146-9450-454b08f9dd85",
  "7c7aed82-3ce3-4ec6-890b-dbc20a78d91c",
  "ced0e9ef-60a1-4d75-9192-7edca96fb57f"
];

(async () => {
  console.log("🚨 Starting AUTH deletion...");

  for (const id of IDS) {
    console.log(`Deleting Auth user: ${id}`);

    const { error } = await supabaseAdmin.auth.admin.deleteUser(id);

    if (error) {
      console.error("❌ Auth delete error:", error.message);
    } else {
      console.log(`✔ Deleted: ${id}`);
    }
  }

  console.log("🎉 Auth cleanup complete!");
})();
