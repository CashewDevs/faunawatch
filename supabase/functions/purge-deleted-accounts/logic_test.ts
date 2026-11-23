// Run with: deno test supabase/functions/purge-deleted-accounts/logic_test.ts
import { assertEquals } from "jsr:@std/assert@1.0.8";
import { removalBatches, summarize } from "./logic.ts";

Deno.test("files are grouped by bucket, without duplicates or blanks", () => {
  assertEquals(
    removalBatches([
      { bucket_id: "avatars", name: "u1/me.png" },
      { bucket_id: "report-images", name: "r1/a.jpg" },
      { bucket_id: "avatars", name: "u1/me.png" },
      { bucket_id: "report-images", name: "r1/b.jpg" },
      { bucket_id: "", name: "x" },
      { bucket_id: "chat-images", name: "" },
    ]),
    [
      ["avatars", ["u1/me.png"]],
      ["report-images", ["r1/a.jpg", "r1/b.jpg"]],
    ],
  );
});

Deno.test("large buckets are split into batches", () => {
  const objects = Array.from({ length: 5 }, (_, i) => ({
    bucket_id: "chat-images",
    name: `u1/t1/${i}.webp`,
  }));
  assertEquals(removalBatches(objects, 2).map(([, names]) => names.length), [2, 2, 1]);
});

Deno.test("no files, no batches", () => {
  assertEquals(removalBatches([]), []);
  assertEquals(removalBatches(null), []);
});

Deno.test("summary counts outcomes only", () => {
  assertEquals(summarize(["deleted", "deleted_no_email", "failed", "deleted"]), {
    due: 4,
    deleted: 3,
    emailFailed: 1,
    failed: 1,
  });
  assertEquals(summarize([]), { due: 0, deleted: 0, emailFailed: 0, failed: 0 });
});
