// Run with: deno test supabase/functions/send-push/logic_test.ts
import { assertEquals } from "jsr:@std/assert@1.0.8";
import {
  buildData,
  buildFcmMessage,
  groupKey,
  isInvalidTokenResponse,
  type NotificationRecord,
  shouldSend,
} from "./logic.ts";

const row: NotificationRecord = {
  id: "n1",
  user_id: "u1",
  type: "chat_message",
  title: "Sam",
  body: "Hello",
  thread_id: "t1",
  report_id: null,
  read_at: null,
  created_at: "2026-11-20T10:00:00Z",
};

Deno.test("INSERT always sends", () => {
  assertEquals(
    shouldSend({ type: "INSERT", table: "notifications", record: row }),
    true,
  );
});

Deno.test("UPDATE sends only for a grouped refresh", () => {
  const old = { ...row, created_at: "2026-11-20T09:00:00Z" };
  const update = (record: NotificationRecord, old_record: NotificationRecord) =>
    shouldSend({ type: "UPDATE", table: "notifications", record, old_record });
  assertEquals(update(row, old), true);
  // Mark read: created_at unchanged.
  assertEquals(update({ ...row, read_at: "2026-11-20T10:05:00Z" }, row), false);
  // Mark unread: created_at unchanged.
  assertEquals(update(row, { ...row, read_at: "2026-11-20T10:05:00Z" }), false);
  // created_at changed but the row is read: no push.
  assertEquals(update({ ...row, read_at: "2026-11-20T10:05:00Z" }, old), false);
});

Deno.test("DELETE, other tables and bad rows never send", () => {
  assertEquals(shouldSend({ type: "DELETE", record: null }), false);
  assertEquals(shouldSend({ type: "INSERT", table: "reports", record: row }), false);
  assertEquals(shouldSend({ type: "INSERT", record: null }), false);
});

Deno.test("group key is per chat thread or report and fits APNs", () => {
  assertEquals(groupKey(row), "chat-t1");
  assertEquals(
    groupKey({ ...row, thread_id: null, report_id: "r1", type: "report_like" }),
    "report-r1-report_like",
  );
  assertEquals(groupKey({ ...row, thread_id: null }), "n-n1");
  const long = groupKey({ ...row, thread_id: "x".repeat(100) });
  assertEquals(long.length, 64);
});

Deno.test("data holds only strings and tolerates unknown types", () => {
  assertEquals(buildData({ ...row, type: "something_new", thread_id: null }), {
    notification_id: "n1",
    type: "something_new",
    report_id: "",
    thread_id: "",
  });
  const message = buildFcmMessage(row, "tok").message;
  assertEquals(message.token, "tok");
  assertEquals(message.notification, { title: "Sam", body: "Hello" });
  assertEquals(message.android.notification.tag, "chat-t1");
  assertEquals(message.android.priority, "HIGH");
  assertEquals(message.android.notification.channel_id, "faunawatch_default");
  assertEquals(
    message.android.notification.notification_priority,
    "PRIORITY_HIGH",
  );
  assertEquals(message.android.notification.sound, "default");
  assertEquals(message.apns.headers["apns-collapse-id"], "chat-t1");
});

Deno.test("only dead tokens are reported invalid", () => {
  assertEquals(
    isInvalidTokenResponse(404, {
      error: {
        status: "NOT_FOUND",
        details: [{ errorCode: "UNREGISTERED" }],
      },
    }),
    true,
  );
  assertEquals(
    isInvalidTokenResponse(400, {
      error: {
        status: "INVALID_ARGUMENT",
        message: "The registration token is not a valid FCM registration token",
      },
    }),
    true,
  );
  assertEquals(
    isInvalidTokenResponse(400, {
      error: { status: "INVALID_ARGUMENT", message: "Invalid JSON payload" },
    }),
    false,
  );
  assertEquals(
    isInvalidTokenResponse(500, { error: { status: "INTERNAL" } }),
    false,
  );
  assertEquals(isInvalidTokenResponse(500, null), false);
});
