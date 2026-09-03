# Setup guide

## What changed
- **Theme picker**: the three theme cards are now side-by-side (stacking only on narrow phones), each with just an icon, name, and one line — no more scrolling through full previews before picking.
- **Content storage**: goals that visitors see now live in a Supabase database table (`goals`), not hardcoded in the HTML/JS.
- **Suggestions**: visitors can submit a suggestion, which lands in a separate `suggestions` table with `status = pending`. It does **not** show up on the site.
- **Admin review**: `admin.html` is a separate, password-protected page where you sign in, see pending suggestions, and Approve (moves it into `goals`, visible to everyone) or Reject.
- **Tailored plans**: the “Plan” action sends the selected goal to a Supabase Edge Function, which uses the OpenAI API to create actionable steps. Plans are not stored or hardcoded in the site.
- The old approach — writing straight to a GitHub file using a personal access token embedded in the page source — is gone. That token was visible to anyone who viewed the page source, which is a real security problem for a public GitHub Pages site.

## 1. Create a Supabase project
1. Go to [supabase.com](https://supabase.com) → New project (the free tier is enough for this).
2. Wait for it to finish provisioning (~2 minutes).

## 2. Run the schema
1. In your project, open **SQL Editor** → **New query**.
2. Paste in the entire contents of `supabase_setup.sql` and click **Run**.
3. This creates the `topics`, `goals`, and `suggestions` tables, sets up the security rules, and seeds it with all the existing goals so nothing is lost.

## 3. Create your admin login
1. Go to **Authentication → Users → Add user** (create user manually).
2. Enter an email and password — this is what you'll use to log into `admin.html`.
3. You don't need to set up anything else — any signed-in user is treated as admin, and since you control who you create here, that's just you.

## 4. Get your API keys
1. Go to **Settings → API**.
2. Copy the **Project URL** and the **anon / public key**.
   - The anon key is *safe* to put in public client-side code — it can only do what the security rules (`supabase_setup.sql`) allow, which is: read topics/goals, and submit suggestions. It cannot read other people's suggestions or write goals directly.
   - Never use the **service_role** key in these files — that one bypasses all security rules.

## 5. Plug the keys in
In **both** `index.html` and `admin.html`, find:
```js
const SUPABASE_URL      = "__SUPABASE_URL__";
const SUPABASE_ANON_KEY = "__SUPABASE_ANON_KEY__";
```
and replace the two placeholder strings with your actual values.

## 6. Deploy
- Commit and push `index.html`, `admin.html`, and (optionally, for your own reference) `supabase_setup.sql` and this file to your GitHub Pages repo.
- `admin.html` isn't linked from the public site anywhere — you just visit it directly at `https://yoursite.github.io/admin.html` when you want to review suggestions. Its login screen is the only thing protecting it, so keep your admin password private.

## 7. Deploy the plan generator
The client calls an Edge Function named `generate-goal-plan`. Its source is in `supabase/functions/generate-goal-plan/index.ts`; the OpenAI key stays on Supabase and is never exposed in `index.html`.

1. Install and sign in to the [Supabase CLI](https://supabase.com/docs/guides/cli).
2. Link this folder to your project, then set the server-only OpenAI secret:
   ```bash
   supabase link --project-ref YOUR_PROJECT_REF
   supabase secrets set OPENAI_API_KEY=your_openai_api_key
   ```
3. Deploy the function with JWT verification enabled:
   ```bash
   supabase functions deploy generate-goal-plan
   ```
4. In the OpenAI dashboard, set an appropriate project budget and usage limits. The function uses `gpt-5-mini` by default; override it without a code change by setting `OPENAI_MODEL`:
   ```bash
   supabase secrets set OPENAI_MODEL=gpt-5-mini
   ```

The public site sends only the selected goal, topic, difficulty, and theme. The function validates those values, returns 3–7 plain-text steps, and does not persist them. If the function or OpenAI is unavailable, visitors see a retry message instead of a generic, hardcoded plan.

## Reviewing suggestions going forward
1. Visit `admin.html`, sign in.
2. Each pending suggestion shows its realm, difficulty, and text.
3. **Approve** copies it into the live `goals` table (visitors will see it immediately) and marks it approved.
4. **Reject** just marks it rejected — it won't show up again and won't be added to the live list.
