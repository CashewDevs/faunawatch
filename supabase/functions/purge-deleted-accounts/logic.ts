// Pure helpers for purge-deleted-accounts: no network, no environment access
// (see logic_test.ts).

/** A row of public.account_storage_objects(). */
export interface StorageObject {
  bucket_id: string;
  name: string;
}

/** Storage removes at most this many paths per call. */
export const REMOVE_BATCH = 100;

/** How many due accounts one run deletes; the rest wait for the next run. */
export const ACCOUNTS_PER_RUN = 20;

/**
 * The files to remove, as [bucket, paths] batches of at most [size] paths.
 * Rows without a bucket or path are skipped; duplicates are removed once.
 */
export function removalBatches(
  objects: readonly StorageObject[] | null | undefined,
  size: number = REMOVE_BATCH,
): Array<[string, string[]]> {
  const byBucket = new Map<string, Set<string>>();
  for (const object of objects ?? []) {
    if (!object?.bucket_id || !object?.name) continue;
    const names = byBucket.get(object.bucket_id) ?? new Set<string>();
    names.add(object.name);
    byBucket.set(object.bucket_id, names);
  }
  const batches: Array<[string, string[]]> = [];
  for (const [bucket, names] of byBucket) {
    const list = [...names];
    for (let i = 0; i < list.length; i += size) {
      batches.push([bucket, list.slice(i, i + size)]);
    }
  }
  return batches;
}

/** What happened to one account. */
export type PurgeOutcome =
  | "deleted" // files and account deleted, email sent (or not needed)
  | "deleted_no_email" // deleted, but the email couldn't be sent
  | "failed"; // nothing more deleted this run; tried again next hour

/** The run's totals, safe to log and return (no ids or addresses). */
export function summarize(outcomes: readonly PurgeOutcome[]): Record<string, number> {
  return {
    due: outcomes.length,
    deleted: outcomes.filter((o) => o !== "failed").length,
    emailFailed: outcomes.filter((o) => o === "deleted_no_email").length,
    failed: outcomes.filter((o) => o === "failed").length,
  };
}
