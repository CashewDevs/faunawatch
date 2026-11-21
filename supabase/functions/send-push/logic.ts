// Pure helpers for send-push: no network, no environment access, so they are
// easy to unit test (see logic_test.ts).

/** A row of public.notifications, as sent by the Database Webhook. */
export interface NotificationRecord {
  id: string;
  user_id: string;
  type?: string | null;
  title?: string | null;
  body?: string | null;
  report_id?: string | null;
  thread_id?: string | null;
  read_at?: string | null;
  created_at?: string | null;
}

/** The Database Webhook payload for public.notifications. */
export interface WebhookPayload {
  type: string; // INSERT | UPDATE | DELETE
  table?: string;
  schema?: string;
  record?: NotificationRecord | null;
  old_record?: NotificationRecord | null;
}

/**
 * Whether this event should produce a push.
 *
 * - INSERT: always (a new notification).
 * - UPDATE: only a grouped refresh, which is how chat and like notifications
 *   are repeated: created_at moved and the row is still unread. Mark read,
 *   mark unread and any other update never push.
 * - Anything else (DELETE, other tables): never.
 */
export function shouldSend(payload: WebhookPayload): boolean {
  if (payload.table !== undefined && payload.table !== "notifications") {
    return false;
  }
  const record = payload.record;
  if (!record || typeof record.id !== "string" || !record.user_id) return false;
  if (payload.type === "INSERT") return true;
  if (payload.type === "UPDATE") {
    const old = payload.old_record;
    if (!old) return false;
    return record.read_at == null &&
      record.created_at != null &&
      record.created_at !== old.created_at;
  }
  return false;
}

/** Must match AndroidNotificationChannel and the AndroidManifest meta-data. */
export const ANDROID_CHANNEL_ID = "faunawatch_default";

/** Longest apns-collapse-id APNs accepts, in bytes. */
const MAX_COLLAPSE_ID = 64;

/**
 * A stable key per conversation or report, so a grouped notification replaces
 * the previous one on the device instead of stacking. Unknown types fall back
 * to the notification id (no grouping).
 */
export function groupKey(record: NotificationRecord): string {
  let key: string;
  if (record.thread_id) {
    key = `chat-${record.thread_id}`;
  } else if (record.report_id) {
    key = `report-${record.report_id}-${record.type ?? "other"}`;
  } else {
    key = `n-${record.id}`;
  }
  return key.slice(0, MAX_COLLAPSE_ID);
}

/** The `data` of the push; FCM requires string values. */
export function buildData(record: NotificationRecord): Record<string, string> {
  return {
    notification_id: record.id,
    type: record.type ?? "",
    report_id: record.report_id ?? "",
    thread_id: record.thread_id ?? "",
  };
}

/** An FCM HTTP v1 request body for one device token. */
export function buildFcmMessage(record: NotificationRecord, token: string) {
  const key = groupKey(record);
  return {
    message: {
      token,
      notification: {
        title: record.title || "FaunaWatch",
        body: record.body ?? "",
      },
      data: buildData(record),
      android: {
        priority: "HIGH",
        // Same tag = the new notification replaces the old one on the device.
        // (No collapse_key: FCM allows only four distinct ones per device.)
        // channel_id: the high-importance channel the app creates at start, so
        // the notification pops up on screen.
        notification: {
          channel_id: ANDROID_CHANNEL_ID,
          notification_priority: "PRIORITY_HIGH",
          tag: key,
          sound: "default",
        },
      },
      apns: {
        headers: { "apns-priority": "10", "apns-collapse-id": key },
        payload: { aps: { sound: "default", "thread-id": key } },
      },
    },
  };
}

/**
 * Whether an FCM error response means the token is dead and should be
 * deleted: UNREGISTERED (404), or INVALID_ARGUMENT about the token itself (not
 * about the rest of the message).
 */
export function isInvalidTokenResponse(
  status: number,
  body: unknown,
): boolean {
  const error = (body as { error?: Record<string, unknown> } | null)?.error;
  if (!error) return false;
  const details = Array.isArray(error.details) ? error.details : [];
  const codes = details
    .map((d) => (d as { errorCode?: unknown })?.errorCode)
    .filter((c): c is string => typeof c === "string");
  if (codes.includes("UNREGISTERED") || error.status === "NOT_FOUND") {
    return true;
  }
  if (status === 404) return true;
  if (error.status === "INVALID_ARGUMENT" || codes.includes("INVALID_ARGUMENT")) {
    return /token/i.test(String(error.message ?? ""));
  }
  return false;
}
