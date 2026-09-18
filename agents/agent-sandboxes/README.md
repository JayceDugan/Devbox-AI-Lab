# Agent sandboxes

Per-role coding-agent sandboxes for OpenShell. Each agent is a small
buildable unit: **one directory, one image, one network contract, one
persona**.

```
agent-sandboxes/
  README.md                  # this file
  profiles/                  # layer 1: GitHub credential+policy profiles (per role)
    github-feature.yaml      #   clone/push + PR lifecycle (create/edit/close/comment)
    github-review.yaml       #   read + review feedback (comments/reviews), no push
    github-architect.yaml    #   read-only planning
  pi/                        # base pi coding agent (generic)
  pi-developer/                # feature developer (persona: build features, deliver as PRs)
```

## The three layers

1. **Provider profile** (`profiles/*.yaml`) — the *credential boundary*.
   The gateway composes the profile's endpoints into every attached
   sandbox's effective policy, and the token **only resolves on endpoints
   declared by the profile**. This is the "configurable GitHub policy"
   layer: one profile per role, importable/upsertable independently of any
   agent image. The credential itself is configured directly on the
   provider, e.g. `GITHUB_TOKEN=ghp_... openshell provider create --name
   github --type github-feature --credential GITHUB_TOKEN` (same shape as
   any other provider: `--credential KEY` reads the env var, so the secret
   never lands in shell history or files).

2. **Agent image** (`<agent>/`) — the *buildable unit*:
   - `agent-config/` → copied to `/sandbox/.pi/agent/`: pi's full config —
     `AGENTS.md` (persona + hard limits, loaded as pi's global context),
     `models.json` (inference provider/model), skills, extensions.
   - `policy.yaml` — the sandbox network contract (filesystem + network),
     baked into the image at `/etc/openshell/policy.yaml` and used as the
     create-time default.
   - Git-over-https auth: the image bakes the same `/sandbox/.gitconfig` that
     `gh auth setup-git` writes, pointing git at `gh`'s built-in
     `gh auth git-credential` helper. It reads the provider-injected
     `GITHUB_TOKEN` (placeholder) at request time; the supervisor rewrites
     the Authorization header in transit. No secret in the image, no custom
     scripts.
   - `Containerfile`, `build.sh`, `run.sh`.

3. **Sandbox instance** — `run.sh` does
   `openshell sandbox create --from <image> --provider <name>`.
   Effective policy = policy.yaml ∪ provider-profile endpoints. Network
   rules hot-update at runtime (`openshell policy update/set --wait`);
   filesystem/landlock/process fields require recreation.

## How policy composition works (the "concatenation" question)

- The provider profile's endpoints and the sandbox policy's endpoints are
  **all** present in the effective policy (`openshell policy get <sbx>
  --full` shows the `_provider_*` composed entries).
- Allow rules from overlapping endpoints are **unioned**: a request is
  admitted if a matching endpoint allows it.
- **Deny rules always take precedence** over allows, on any matching
  endpoint.
- A broad `access: read-only` endpoint does **not** block narrower explicit
  allow rules on more specific paths — verified live: POST
  `/repos/JayceDugan/*/pulls` is admitted while `read-only` still covers the
  rest of `api.github.com`, and POST `/issues` is denied (403
  `policy_denied`, layer l7).
- The L7 parser is chosen by **most-specific path** (e.g. `/graphql`
  selects GraphQL inspection, where per-operation/mutation rules apply —
  `gh pr close` uses the `closePullRequest` GraphQL mutation and is denied
  unless the policy allows that field).
- A sandbox policy allow **cannot expand** the credential boundary: static
  credentials resolve only on the provider profile's endpoints. If you add
  an endpoint to policy.yaml, mirror it in the profile or the token won't
  be injected there.

## Agents

| Agent       | Image                                    | Persona            | GitHub provider attached | Inference                     |
|-------------|------------------------------------------|--------------------|--------------------------|-------------------------------|
| `pi`        | `ai-lab/openshell-pi-sandbox`            | generic coding     | `github` (feature, classic token) | workspace route (`inference.local`) |
| `pi-developer` | `ai-lab/openshell-pi-developer-sandbox`  | feature developer  | `github` (feature, fine-grained PAT) | workspace route (`inference.local`) |
| `pi-pr-review` | `ai-lab/openshell-pi-pr-review-sandbox` | PR review (read + comment/review) | `github-review` (fine-grained PAT) | workspace route (`inference.local`) |

Inference is configured **workspace-level** (`openshell inference set`),
so `https://inference.local/v1` in `models.json` resolves for every
sandbox without per-sandbox provider attachment.

## Using a different GitHub token (per agent / per role)

Tokens live on **providers**, not in images or policy files. A provider is a
triple: `(name, credential value, profile type)` — the profile type sets the
network boundary, the credential is the token. Any number of providers can
share one profile; that's how the same agent image runs under a different
identity (e.g. a review-bot account).

The review agent was set up exactly this way with a fine-grained PAT:

```bash
# one-time: create a provider for the review role under a different token
GITHUB_TOKEN=github_pat_... openshell provider create \
  --name github-review --type github-review --credential GITHUB_TOKEN

# launch the agent under it (run.sh takes the provider as 2nd arg)
./run.sh pr-review-agent github-review
```

Other operations:

```bash
# rotate the token on an existing provider (running sandboxes pick up the
# new value on the next request; nothing to restart or recreate)
GITHUB_TOKEN=<new-token> openshell provider update github-review --credential GITHUB_TOKEN

# inspect (never prints the credential value)
openshell provider get github-review

# launch the SAME image under a third identity
GITHUB_TOKEN=<bot-token> openshell provider create \
  --name github-review-bot --type github-review --credential GITHUB_TOKEN
./run.sh pr-review-bot github-review-bot
```

### Token scope guidance per role

| Role | Classic token | Fine-grained PAT permissions (least privilege) |
|------|---------------|------------------------------------------------|
| Feature delivery | `repo` | Contents Read/Write, Pull requests Read/Write, Issues Read/Write |
| PR review | `repo` (overkill) | Contents **Read** (clone), Pull requests **Read** (view/diff) + **Write** (formal reviews), Issues Read/**Write** (comments) |
| Architect / planning | `repo` (overkill) | Contents **Read**, Pull requests **Read** |

Notes from live testing:

- A fine-grained PAT with Contents Read + Pull requests **Read** can clone,
  view, and comment, but **cannot** create/submit formal reviews
  (`403 Resource not accessible by personal access token`). Add
  Pull requests **Write** if the review agent should approve /
  request-changes — then re-run the `provider update` command above; no
  image, profile, or policy change is needed.
- `gh` subcommands that hit GraphQL (e.g. `gh pr close --comment` uses the
  `addComment` mutation) must be covered by the profile's GraphQL rules too —
  policy, not token scope, governs those denials (`policy_denied`, layer
  `l7` in the logs).
- Repository access is also limited by the fine-grained PAT's repo selector
  ("All repositories" vs a specific list) — a clone of a repo outside that
  list fails with `404`, not a policy deny.

## Adding a new agent

`pi-pr-review` is the reference example — a full read-only-code reviewer with
its own persona, policy, and fine-grained-token provider. To add another role
(e.g. `pi-architect`):

1. `cp -r pi-pr-review pi-architect`
2. Rewrite `agent-config/AGENTS.md` for the role (e.g. planning persona:
   explore repos/issues/history, produce plans; no review feedback either).
3. One-time gateway setup for the role profile:
   ```bash
   openshell provider profile import --file profiles/github-architect.yaml
   GITHUB_TOKEN=ghp_... openshell provider create \
     --name github-architect --type github-architect --credential GITHUB_TOKEN
   ```
4. Align `pi-architect/policy.yaml`'s GitHub endpoints with the profile
   (mirror its ruleset — read-only for the architect role).
5. Point `run.sh` at the provider (`--provider github-architect` default).
6. `./build.sh && ./run.sh architect-agent`

The same pattern works for any tool/identity: define (or reuse) a profile
for the credential boundary, copy an agent folder, diverge `AGENTS.md` +
`policy.yaml`, build, run.

## Operating notes

- **Denied requests** appear in `openshell logs <sandbox>` as
  `policy_denied` with the exact missing rule (`layer`, `method`, `path`,
  `binary`, `rule_missing`); OCSF `ALLOWED/DENIED` lines show which policy
  and engine (e.g. `engine:l7-graphql`) decided. Use that to iterate:
  `openshell policy update <sbx> --add-allow '...' --wait`, or full YAML
  replace via `openshell policy set <sbx> --policy ... --wait` (network
  fields hot-reload; static fields need recreation).
- **`gh` repo commands** need a git context: run inside a cloned repo or
  set `GH_REPO=owner/repo`. Use `GH_DEBUG=api` to see exactly what `gh`
  sends (REST vs GraphQL) when debugging a deny.
- **Rebuilding the image** only changes the baked defaults (policy,
  agent-config); a running sandbox keeps its live policy until you
  `policy set` / recreate it.
- **Token hygiene**: the token lives only in the gateway (provider
  credential) and as an in-transit substitution. The sandbox sees a
  placeholder in `GITHUB_TOKEN`; images, policy files, and agent configs
  never contain it.

### Pitfalls learned the hard way

- **`gh` has two parallel API paths (REST and GraphQL)** — cover both in
  policy. `gh pr close --comment` issues the GraphQL `addComment` mutation
  even though the REST `POST /issues/comments` rule looks equivalent; and
  `gh pr review` (newer gh) issues `addPullRequestReview` /
  `submitPullRequestReview` GraphQL mutations rather than the REST
  `POST /pulls/*/reviews`. Allow-list the GraphQL fields you expect:
  feature role: `createPullRequest`, `updatePullRequest`, `closePullRequest`,
  `reopenPullRequest`, `addComment`, `updateComment`, `deleteComment`;
  review role: `addPullRequestReview`, `submitPullRequestReview`,
  `updatePullRequestReview`.
- **GitHub API gotchas (not policy)**: a user can only have ONE pending
  review per PR — a stuck pending review blocks new review creation for
  that user ("User can only have one pending review per pull request");
  the REST submit-review-events endpoint (`POST /pulls/*/reviews/*/events`)
  takes **uppercase** event values (`COMMENT`, `APPROVE`,
  `REQUEST_CHANGES`); and fine-grained PAT scope denials look like
  `403 Resource not accessible by personal access token` (distinct from
  sandbox `policy_denied` 403s, which carry a JSON body naming the missing
  rule).
- **Credentialed hosts must not be L4-only anywhere.** If a provider
  profile declares `github.com:443` / `api.github.com:443` as credentialed
  endpoints, every other rule touching those hosts (e.g. the pypi/uv rule)
  must use an inspected protocol (`protocol: rest` + `access`/`rules`).
  `policy set` hard-rejects L4-only credentialed endpoints; at creation the
  gateway warns and the sandbox proxy denies the uninspected traffic.
- **Profile updates are file-based with optimistic concurrency:** export the
  current profile (keeps `resource_version`), edit, then
  `openshell provider profile update --file <f> <id>`; `import` only works
  for new profiles. Re-sync `resource_version` in the checked-in file after
  each update.
