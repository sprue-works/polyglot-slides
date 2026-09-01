# Polyglot Slides agent notes

## `gh api` query parameters need an explicit GET

`gh api -f key=value` changes the request method from GET to POST unless
`--method GET` is supplied. When adding query-string filters to a read-only
GitHub API request, always write `gh api --method GET ... -f key=value`; an
implicit POST commonly returns a misleading 404 for collection endpoints.

## Start rebases with the signing override when 1Password is unavailable

Mario's global Git config signs every commit through the 1Password SSH agent,
so a rebase also tries to sign every rewritten commit. If that agent is
unavailable, start the rebase with
`git -c commit.gpgsign=false rebase <upstream>`. Do not switch signing modes or
manually commit halfway through a stalled rebase; doing so can duplicate its
todo entries. Abort back to the untouched branch and restart cleanly instead.
