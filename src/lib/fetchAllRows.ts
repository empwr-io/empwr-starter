/**
 * PostgREST caps every response at 1000 rows on Supabase's hosted default, and the cap
 * is applied SILENTLY. `.limit(50000)` returns 1000 rows with no error and no warning,
 * so a truncated result looks exactly like a complete one. A report built on it is
 * confidently wrong, which is worse than one that is obviously broken.
 *
 * Any query that could legitimately exceed 1000 rows pages through with `.range()`.
 *
 *   const rows = await fetchAllRows<ClientRow>((from, to) =>
 *     supabase.from("v_client_register").select("*").order("name").range(from, to)
 *   );
 *
 * Pass a STABLE `.order(...)`. Without one, pages can overlap or skip rows between
 * requests and you will lose records with no error to tell you.
 */

export type PageResult<T> = { data: T[] | null; error: { message: string } | null };

export async function fetchAllRows<T>(
  page: (from: number, to: number) => PromiseLike<PageResult<T>>,
  opts: { pageSize?: number; cap?: number } = {},
): Promise<T[]> {
  const size = opts.pageSize ?? 1000;
  const cap = opts.cap ?? 100_000; // runaway guard, a table scan should never be unbounded
  const out: T[] = [];

  for (let from = 0; from < cap; from += size) {
    const { data, error } = await page(from, from + size - 1);
    if (error) throw new Error(error.message);
    const batch = data ?? [];
    out.push(...batch);
    if (batch.length < size) return out; // a short page is the last page
  }

  throw new Error(`fetchAllRows hit the ${cap} row cap. Narrow the query or raise the cap deliberately.`);
}
