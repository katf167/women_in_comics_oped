#!/usr/bin/env python3
"""
Autograder for the Final-Project (Op-Ed with Data Visualisation).

Scoring
-------
Structure requirements            50 pts
Functionality (run.R + figures)   20 pts
Code readability – tidyverse       3 pts
----------------------------------------
Base total                        73 pts
Extra credit
  • Early & consistent commits   ≤15 pts
  • End-of-course survey      (listed only)

A non-perfect, on-time submission exits
with code 1 so the PR check shows ❌.
"""
import os, sys, json, subprocess, shutil, re, datetime, requests, pytz
from dateutil import parser
from pathlib import Path

# ───────────────────────── CONFIG ─────────────────────────
DUE_ET = datetime.datetime(2025, 5, 9, 18, 0, 0,
                           tzinfo=pytz.timezone("US/Eastern"))
EARLY_EC_PER_DAY = 5
EARLY_EC_MAX = 15
EXCLUDE_EC_AUTHORS = {
    "chohlasa",
    "github-actions[bot]",
    "auto-commit-bot",
    "dependabot[bot]",
}

# ───────────────────────── HELPERS ─────────────────────────
def et(dt_str):
    return parser.isoparse(dt_str).astimezone(pytz.timezone("US/Eastern"))

def github_api(url, token):
    r = requests.get(url, headers={"Authorization": f"Bearer {token}",
                                   "Accept": "application/vnd.github+json"})
    r.raise_for_status()
    return r.json()

def pr_metadata():
    ev_path = os.environ["GITHUB_EVENT_PATH"]
    with open(ev_path, encoding="utf-8") as f:
        data = json.load(f)
    repo = data["repository"]["full_name"]          # org/repo
    pr_num = data["number"]
    return repo, pr_num

# ───────────────────────── GRADING ─────────────────────────
def grade_structure_requirements(readme):
    """
    50 pts if README.md:
      • starts with a title ('# ')
      • second non-empty line is italic author(s)
      • ≥1 figure embed
      • ends with 'Source data:' line
      • body word-count ∈ [500,800]  (captions excluded)
    Always prints the body word-count.
    """
    if not readme.exists():
        print("Structure – README.md missing ⇒ 0/50")
        return 0
    lines = readme.read_text(encoding="utf-8").splitlines()
    nonempty = [ln for ln in lines if ln.strip()]

    # ── structural checks ──
    if not nonempty or not nonempty[0].startswith("# "):
        print("Structure – missing title line ⇒ 0/50"); return 0
    if len(nonempty) < 2 or not (nonempty[1].startswith("*") and
                                 nonempty[1].endswith("*")):
        print("Structure – missing italic author line ⇒ 0/50"); return 0
    if not any(re.search(r"!\[.*?\]\(figs/[^)]+\)", ln, flags=re.I)
               for ln in lines):
        print("Structure – no figure embed ⇒ 0/50"); return 0
    if not any(re.match(r"\*?Source data:", ln, flags=re.I) for ln in lines):
        print("Structure – no 'Source data:' line ⇒ 0/50"); return 0

    # ── body word-count (skip images & captions) ──
    body_lines = []
    in_body, prev_was_image = False, False
    for ln in lines:
        if not in_body:
            # body starts *after* the italic author line
            if ln.strip() and ln.startswith("*") and ln.endswith("*"):
                in_body = True
            continue

        # stop at Source data
        if re.match(r"\*?Source data:", ln, flags=re.I):
            break

        stripped = ln.strip()
        # skip image embed
        if stripped.startswith("!"):
            prev_was_image = True
            continue
        # skip caption line (first non-empty line after an image)
        if prev_was_image:
            if stripped:                       # treat this as caption
                prev_was_image = False
                continue
            # if it's an empty line we keep the flag until we see text
            continue
        prev_was_image = False
        body_lines.append(ln)

    words = re.findall(r"\b\w+\b", "\n".join(body_lines))
    wc = len(words)
    print(f"Structure – body word-count: {wc}")

    if not (500 <= wc <= 800):
        print("Structure – word-count outside 500–800 ⇒ 0/50")
        return 0
    print("Structure – all checks passed ⇒ 50/50")
    return 50

def grade_functionality(repo_root, readme):
    """
    20 pts if run.R executes (exit 0) and recreates every figure linked
    from the README.
    """
    if not readme.exists():
        print("Functionality – README.md missing ⇒ 0/20"); return 0
    txt = readme.read_text(encoding="utf-8")
    fig_links = re.findall(r"\((?:\./)?(figs/[^)]+)\)", txt, flags=re.I)
    expected_figs = {os.path.normpath(p) for p in fig_links
                     if p.lower().startswith("figs/")}
    if not expected_figs:
        print("Functionality – no figures found in README.md, not possible to test ⇒ 0/20"); return 0

    figs_dir = repo_root / "figs"
    shutil.rmtree(figs_dir, ignore_errors=True)
    figs_dir.mkdir(exist_ok=True)

    res = subprocess.run(["Rscript", "run.R"], cwd=repo_root)
    if res.returncode != 0:
        print("Functionality – run.R failed ⇒ 0/20"); return 0

    created = {str(p.relative_to(repo_root)) for p in figs_dir.rglob("*")
               if p.is_file()}
    missing = expected_figs - created
    if missing:
        print(f"Functionality – missing {len(missing)} figure(s): "
              f"{', '.join(sorted(missing))} ⇒ 0/20")
        return 0
    print(f"Functionality – all {len(expected_figs)} figure(s) reproduced ⇒ 20/20")
    return 20

def grade_style(repo_root):
    """
    3 pts if all .R files conform to the tidyverse style guide
    (styler::style_dir(dry='fail')).
    """
    cmd = "styler::style_dir('.', dry='fail')"
    res = subprocess.run(["Rscript", "-e", cmd], cwd=repo_root,
                         capture_output=True)
    if res.returncode == 0:
        print("Style – tidyverse style pass ⇒ 3/3")
        return 3
    print("Style – `styler` found R files that did not conform to tidyverse style guide ⇒ 0/3")
    return 0

def extra_credit_early_commits(commits):
    days = {
        et(c["commit"]["committer"]["date"]).strftime("%Y-%m-%d")
        for c in commits
        if c.get("author")
        and c["author"]["login"] not in EXCLUDE_EC_AUTHORS
        and et(c["commit"]["committer"]["date"]) < DUE_ET
    }
    pts = EARLY_EC_PER_DAY * min(len(days), EARLY_EC_MAX // EARLY_EC_PER_DAY)
    print(f"EC – early commits on {sorted(days)} ⇒ +{pts}")
    return pts

def survey_netids(repo_root):
    f = repo_root / "src" / "survey.txt"
    if not f.exists():
        print("Survey – survey.txt not found")
        return []
    netids = [ln.strip() for ln in f.read_text(encoding="utf-8").splitlines()
              if ln.strip()]
    if netids:
        print(f"Survey – NetIDs submitted: {', '.join(netids)}")
    else:
        print("Survey – survey.txt present but empty")
    return netids

# ───────────────────────── MAIN ─────────────────────────
def main():
    token = os.environ.get("GITHUB_TOKEN", "")
    repo_root = Path("student-code")
    readme = repo_root / "README.md"

    repo, pr_num = pr_metadata()
    commits = github_api(
        f"https://api.github.com/repos/{repo}/pulls/{pr_num}/commits", token)

    commit_times = [et(c["commit"]["committer"]["date"]) for c in commits]
    last_commit = max(commit_times) if commit_times else None
    late = last_commit and last_commit > DUE_ET
    if last_commit:
        print("Last commit:",
              last_commit.strftime("%Y-%m-%d %H:%M %Z"),
              "(late)" if late else "(on-time)")

    # ── grading ──
    structure = grade_structure_requirements(readme)
    functionality  = grade_functionality(repo_root, readme)
    style = grade_style(repo_root)
    base  = 0 if late else (structure + functionality + style)     # 73 max

    ec_early  = extra_credit_early_commits(commits) if not late else 0
    netids    = survey_netids(repo_root)              # listed only

    # ── summary ──
    print("\n=== SCORE SUMMARY ===")
    print(f"Structure              {structure:>3}/50")
    print(f"Functionality          {functionality:>3}/20")
    print(f"Style                  {style:>2}/3")
    print(f"Total (autogradable):  {base:>3}/73")
    print("\n")
    print("\n=== EXTRA CREDIT ===")
    print(f"Early commits   {ec_early:>3}")
    if netids:
        print(f"Survey EC – the following NetID(s) will receive +5 each:")
        for n in netids:
            print(f"  • {n}")

    # fail PR unless perfect (and on-time)
    if not late and base < 73:
        sys.exit(1)

if __name__ == "__main__":
    main()