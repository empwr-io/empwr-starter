/**
 * Who is actually calling this function.
 *
 * `verify_jwt = true` is NOT an authorisation check. It only requires *a* JWT signed by
 * this project, and the anon key is exactly that, and the anon key ships inside the
 * browser bundle of your site. So anyone who views your page source holds a token that
 * satisfies `verify_jwt`.
 *
 * Every function that reads or changes anything therefore identifies its caller itself.
 * Two callers are legitimate:
 *
 *   service - the service role key, used by scheduled jobs and function-to-function calls
 *   user    - a signed-in staff member's JWT, from the front end
 *
 * The anon key is neither.
 */

// deno-lint-ignore-file no-explicit-any

export type Caller =
  | { kind: "service" }
  | { kind: "user"; id: string; email: string | null };

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
};

/** Handle the browser preflight. Call this first, return the response if you get one. */
export function preflight(req: Request): Response | null {
  return req.method === "OPTIONS" ? new Response("ok", { headers: corsHeaders }) : null;
}

function bearer(req: Request): string {
  return (req.headers.get("Authorization") ?? "").replace(/^Bearer /i, "").trim();
}

/**
 * A plain === on a secret leaks it one byte at a time through timing. This does not.
 */
function timingSafeEqual(a: string, b: string): boolean {
  const enc = new TextEncoder();
  const x = enc.encode(a);
  const y = enc.encode(b);
  let diff = x.length ^ y.length;
  for (let i = 0; i < Math.max(x.length, y.length); i++) diff |= (x[i] ?? 0) ^ (y[i] ?? 0);
  return diff === 0;
}

/**
 * Compares the presented token against the service role key directly, rather than
 * trusting a `role` claim inside the token. A claim is forgeable the moment somebody
 * turns `verify_jwt` off in a hurry, and that is exactly the change made at 6pm.
 */
export function isServiceRole(req: Request): boolean {
  const key = (globalThis as any).Deno?.env?.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!key) return false;
  const token = bearer(req);
  return !!token && timingSafeEqual(token, key);
}

/**
 * Resolve the caller, or get a 403 Response you can hand straight back.
 *
 *   const caller = await requireStaffOrService(req, supabase);
 *   if (caller instanceof Response) return caller;
 */
export async function requireStaffOrService(req: Request, supabase: any): Promise<Caller | Response> {
  if (isServiceRole(req)) return { kind: "service" };

  const token = bearer(req);
  if (!token) return forbidden("No credentials presented.");

  const { data, error } = await supabase.auth.getUser(token);
  if (error || !data?.user) return forbidden("Not a valid staff session.");

  return { kind: "user", id: data.user.id, email: data.user.email ?? null };
}

/** True only for the service role, or a user the database says holds that area. */
export async function requireArea(caller: Caller, area: string, supabase: any): Promise<boolean> {
  if (caller.kind === "service") return true;
  const { data, error } = await supabase.rpc("has_area", { p_user_id: caller.id, p_area: area });
  return !error && data === true;
}

export function forbidden(message: string): Response {
  return new Response(JSON.stringify({ error: message }), {
    status: 403,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
