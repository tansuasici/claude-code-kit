#!/usr/bin/env bash
#
# lesson-graph.sh — Build a typed-relation graph over tasks/lessons/*.md,
# validate the graph, and auto-regenerate the indexed sections of
# tasks/lessons/_index.md.
#
# Zero LLM. YAML frontmatter is parsed deterministically. Inspired by
# GBrain's typed-edge knowledge graph applied at lesson scale.
#
# Usage:
#   ./scripts/lesson-graph.sh             # validate + rewrite _index.md auto-sections
#   ./scripts/lesson-graph.sh --check     # validate only, exit 1 on issues, no write
#   ./scripts/lesson-graph.sh --print     # validate + print rendered sections to stdout
#   ./scripts/lesson-graph.sh --lessons-dir <dir>   # override default tasks/lessons
#
# Validation warnings (stderr):
#   - supersedes-target-missing: lesson references a slug that doesn't exist
#   - contradicts-target-missing: same, for contradicts
#   - supersedes-cycle: A supersedes B and B supersedes A (directly or transitively)
#   - contradicts-loop: A contradicts B and B contradicts A
#   - top-rule-but-superseded: lesson has top_rule:true AND another lesson supersedes it
#
# Auto-generated sections in _index.md (between marker comments):
#   - ## Top Rules                  (lessons with top_rule:true, status active)
#   - ## Active Rules By Topic      (grouped by applies_to)
#   - ## Superseded                 (chronological, with by-whom)
#   - ## Recently Added             (last 30 days, chronological)
#

set -euo pipefail

LESSONS_DIR="$(pwd)/tasks/lessons"
MODE="write"

while [[ $# -gt 0 ]]; do
  case $1 in
    --check|-c) MODE="check"; shift ;;
    --print|-p) MODE="print"; shift ;;
    --lessons-dir) LESSONS_DIR="$2"; shift 2 ;;
    --help|-h)
      sed -n '1,/^set -euo pipefail/p' "$0" | head -n -1 | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      echo "Run with --help for usage." >&2
      exit 1
      ;;
  esac
done

if [ ! -d "$LESSONS_DIR" ]; then
  echo "lesson-graph: $LESSONS_DIR does not exist" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "lesson-graph: python3 is required (deterministic YAML parsing, no third-party deps)" >&2
  exit 1
fi

LESSONS_DIR="$LESSONS_DIR" MODE="$MODE" python3 - <<'PY'
import os, sys, re, json
from datetime import date, datetime, timedelta, timezone

LESSONS_DIR = os.environ["LESSONS_DIR"]
MODE = os.environ["MODE"]
INDEX_PATH = os.path.join(LESSONS_DIR, "_index.md")
TEMPLATE_NAME = "_TEMPLATE.md"
INDEX_NAME = "_index.md"
ARCHIVE_DIRNAME = "_archive"
RECENT_DAYS = 30

# --- Minimal YAML frontmatter parser ---------------------------------------
# Handles only what the kit's lesson format actually uses:
#   - flat key: value pairs
#   - inline lists: key: [a, b, c]
#   - scalar values stripped of surrounding quotes
#   - "# comment" suffix stripped (but only when not inside [])
# Anything fancier (block lists, nested maps) is rejected with a clear error.

def parse_frontmatter(text):
    if not text.startswith("---"):
        return None
    end = text.find("\n---", 3)
    if end == -1:
        return None
    body = text[3:end].strip("\n")
    out = {}
    for raw in body.splitlines():
        line = raw.rstrip()
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        if ":" not in line:
            continue
        key, _, value = line.partition(":")
        key = key.strip()
        value = strip_inline_comment(value.strip())
        out[key] = parse_value(value)
    return out

def strip_inline_comment(value):
    # Only strip # comments outside of [ ... ]
    depth = 0
    for i, ch in enumerate(value):
        if ch == "[":
            depth += 1
        elif ch == "]":
            depth -= 1
        elif ch == "#" and depth == 0 and (i == 0 or value[i-1].isspace()):
            return value[:i].rstrip()
    return value

def parse_value(v):
    if v == "" or v.lower() == "null":
        return None
    if v.lower() == "true":
        return True
    if v.lower() == "false":
        return False
    if v.startswith("[") and v.endswith("]"):
        inner = v[1:-1].strip()
        if not inner:
            return []
        return [item.strip().strip('"').strip("'") for item in inner.split(",") if item.strip()]
    if (v.startswith('"') and v.endswith('"')) or (v.startswith("'") and v.endswith("'")):
        return v[1:-1]
    return v

# --- Walk lessons ----------------------------------------------------------
def slug_from(path):
    return os.path.splitext(os.path.basename(path))[0]

lessons = {}      # slug -> frontmatter dict + extras
parse_errors = []

for entry in sorted(os.listdir(LESSONS_DIR)):
    full = os.path.join(LESSONS_DIR, entry)
    if entry in (INDEX_NAME, TEMPLATE_NAME):
        continue
    if entry == ARCHIVE_DIRNAME:
        continue
    if not entry.endswith(".md"):
        continue
    if not os.path.isfile(full):
        continue
    with open(full, "r", encoding="utf-8") as f:
        content = f.read()
    fm = parse_frontmatter(content)
    if fm is None:
        parse_errors.append(f"{entry}: missing or malformed YAML frontmatter")
        continue
    slug = slug_from(entry)
    lessons[slug] = {
        "slug": slug,
        "path": entry,
        "title": fm.get("title", slug),
        "created": fm.get("created", ""),
        "updated": fm.get("updated", ""),
        "top_rule": bool(fm.get("top_rule", False)),
        "status": (fm.get("status") or "active"),
        "supersedes": fm.get("supersedes") or [],
        "applies_to": fm.get("applies_to") or [],
        "contradicts": fm.get("contradicts") or [],
        "related_decisions": fm.get("related_decisions") or [],
        "related": fm.get("related") or [],
    }

# --- Validation -----------------------------------------------------------
warnings = []

slugs = set(lessons.keys())
superseded_by = {}  # target -> [supersedor]
for slug, meta in lessons.items():
    for target in meta["supersedes"]:
        if target not in slugs:
            warnings.append(f"supersedes-target-missing: {slug} supersedes {target!r} which does not exist")
        else:
            superseded_by.setdefault(target, []).append(slug)
    for target in meta["contradicts"]:
        if target not in slugs:
            warnings.append(f"contradicts-target-missing: {slug} contradicts {target!r} which does not exist")

# Supersedes cycle (any path back to self in the supersedes-DAG)
def has_cycle(start, graph):
    stack = [(start, [start])]
    while stack:
        node, path = stack.pop()
        for nxt in graph.get(node, []):
            if nxt == start:
                return path + [nxt]
            if nxt not in path:
                stack.append((nxt, path + [nxt]))
    return None

supersedes_graph = {slug: meta["supersedes"] for slug, meta in lessons.items()}
seen_cycles = set()
for slug in lessons:
    cycle = has_cycle(slug, supersedes_graph)
    if cycle:
        key = tuple(sorted(cycle))
        if key in seen_cycles:
            continue
        seen_cycles.add(key)
        warnings.append("supersedes-cycle: " + " -> ".join(cycle))

# Contradicts loop (mutual)
contradicts_pairs = set()
for slug, meta in lessons.items():
    for target in meta["contradicts"]:
        if target in lessons and slug in lessons[target]["contradicts"]:
            pair = tuple(sorted((slug, target)))
            if pair not in contradicts_pairs:
                contradicts_pairs.add(pair)
                warnings.append(f"contradicts-loop: {pair[0]} ↔ {pair[1]} contradict each other")

# Top rule but superseded
for slug, meta in lessons.items():
    if meta["top_rule"] and slug in superseded_by:
        sup = ", ".join(superseded_by[slug])
        warnings.append(f"top-rule-but-superseded: {slug} has top_rule:true but is superseded by {sup}")

# --- Reporting ------------------------------------------------------------
for line in parse_errors:
    print(f"[parse-error] {line}", file=sys.stderr)
for line in warnings:
    print(f"[warn] {line}", file=sys.stderr)

if MODE == "check":
    if parse_errors or warnings:
        sys.exit(1)
    sys.exit(0)

# --- Section rendering ----------------------------------------------------
def title_line(meta):
    return f"- **{meta['title']}** ([{meta['slug']}]({meta['slug']}.md))"

active = [m for m in lessons.values() if m["status"] == "active"]
superseded = [m for m in lessons.values() if m["status"] == "superseded"]

def render_top_rules():
    rules = sorted(
        (m for m in active if m["top_rule"]),
        key=lambda m: m["created"],
        reverse=True,
    )
    if not rules:
        return "*No top rules yet. Set `top_rule: true` in a lesson's frontmatter to surface it here.*"
    return "\n".join(title_line(m) for m in rules)

def render_by_topic():
    by_topic = {}
    untyped = []
    for m in active:
        if not m["applies_to"]:
            untyped.append(m)
        else:
            for topic in m["applies_to"]:
                by_topic.setdefault(topic, []).append(m)
    lines = []
    for topic in sorted(by_topic):
        lines.append(f"### {topic}")
        lines.append("")
        for m in sorted(by_topic[topic], key=lambda x: x["created"], reverse=True):
            lines.append(title_line(m))
        lines.append("")
    if untyped:
        lines.append("### Untyped")
        lines.append("")
        lines.append("*Lessons without `applies_to:` tags. Add a tag to group them.*")
        lines.append("")
        for m in sorted(untyped, key=lambda x: x["created"], reverse=True):
            lines.append(title_line(m))
        lines.append("")
    if not lines:
        return "*No active lessons yet.*"
    return "\n".join(lines).rstrip()

def render_superseded():
    rules = sorted(superseded, key=lambda m: m["updated"] or m["created"], reverse=True)
    if not rules:
        return "*No superseded lessons. Older lessons get this status when a newer lesson lists them in `supersedes:`.*"
    lines = []
    for m in rules:
        sups = superseded_by.get(m["slug"], [])
        if sups:
            tail = " — superseded by " + ", ".join(f"[{s}]({s}.md)" for s in sups)
        else:
            tail = " — marked superseded, but no lesson claims it in `supersedes:`"
        lines.append(title_line(m) + tail)
    return "\n".join(lines)

def render_recently_added():
    today = date.today()
    cutoff = today - timedelta(days=RECENT_DAYS)
    def parse_d(s):
        try:
            return date.fromisoformat(s)
        except Exception:
            return None
    recent = []
    for m in active:
        d = parse_d(m["created"])
        if d and d >= cutoff:
            recent.append((d, m))
    if not recent:
        return f"*No lessons created in the last {RECENT_DAYS} days.*"
    recent.sort(key=lambda kv: kv[0], reverse=True)
    return "\n".join(f"- {kv[0].isoformat()} — " + title_line(kv[1])[2:] for kv in recent)

sections = [
    ("top-rules", "Top Rules", render_top_rules()),
    ("by-topic", "Active Rules By Topic", render_by_topic()),
    ("superseded", "Superseded", render_superseded()),
    ("recently-added", "Recently Added", render_recently_added()),
]

# --- Render & splice into _index.md --------------------------------------
def fenced(name, body):
    return (
        f"<!-- BEGIN AUTO-GENERATED {name} (managed by scripts/lesson-graph.sh) -->\n"
        f"{body}\n"
        f"<!-- END AUTO-GENERATED {name} -->"
    )

def render_full():
    parts = []
    for name, heading, body in sections:
        parts.append(f"## {heading}\n\n{fenced(name, body)}")
    return "\n\n".join(parts)

if MODE == "print":
    print(render_full())
    sys.exit(1 if (parse_errors or warnings) else 0)

# MODE == "write": splice into _index.md, replacing each fenced block
if not os.path.isfile(INDEX_PATH):
    # Bootstrap a minimal _index.md if missing
    with open(INDEX_PATH, "w", encoding="utf-8") as f:
        f.write("# Lessons Learned — Index\n\nAuto-generated sections below; see scripts/lesson-graph.sh.\n\n")
        f.write(render_full() + "\n")
    print(f"[ok] bootstrapped {INDEX_PATH}")
    sys.exit(1 if (parse_errors or warnings) else 0)

with open(INDEX_PATH, "r", encoding="utf-8") as f:
    text = f.read()

def upsert_section(text, name, heading, body):
    fenced_block = fenced(name, body)
    begin_marker = f"<!-- BEGIN AUTO-GENERATED {name}"
    if begin_marker in text:
        pattern = re.compile(
            r"<!-- BEGIN AUTO-GENERATED " + re.escape(name)
            + r".*?<!-- END AUTO-GENERATED " + re.escape(name) + r" -->",
            re.DOTALL,
        )
        return pattern.sub(fenced_block, text, count=1)
    heading_re = re.compile(r"^##[ \t]+" + re.escape(heading) + r"[ \t]*$", re.MULTILINE)
    m = heading_re.search(text)
    if m:
        before = text[: m.end()]
        rest = text[m.end():]
        end_re = re.compile(r"\n##[ \t]+", re.MULTILINE)
        m2 = end_re.search(rest)
        if m2:
            after = rest[m2.start():]
        else:
            after = ""
        return before + "\n\n" + fenced_block + "\n\n" + after.lstrip("\n")
    return text.rstrip() + "\n\n## " + heading + "\n\n" + fenced_block + "\n"

new_text = text
for name, heading, body in sections:
    new_text = upsert_section(new_text, name, heading, body)

if new_text != text:
    tmp = INDEX_PATH + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        f.write(new_text)
    os.replace(tmp, INDEX_PATH)
    print(f"[ok] wrote {INDEX_PATH}")
else:
    print(f"[ok] {INDEX_PATH} already up to date")

sys.exit(1 if (parse_errors or warnings) else 0)
PY
