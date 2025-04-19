#!/usr/bin/env python3
"""
Autograder for Assignment 4 (Data‑visualisation).

Scoring
-------
Problem 1  30 pts
  • team commits             18
  • PR requests review       12
Problem 2  40 pts  (run.R executes cleanly)
Problem 3  20 pts  (≥1 figure embedded in README)
Problem 4  10 pts  (≥5 numbered bullets in README)
----------------------------------------------
Base total 100 pts
Extra‑credit  early‑commit days (≤15 pts)

A non‑perfect, on‑time submission exits with code 1 so the PR check shows a ❌.
"""
import os, sys, json, subprocess, shutil, re, datetime, requests, pytz
from dateutil import parser
import pandas as pd   # only needed for EC day count helper

# ---------- global config ----------
DUE_ET = datetime.datetime(2025, 4, 28, 18, 0, 0,
                           tzinfo=pytz.timezone("US/Eastern"))
EARLY_EC_PER_DAY = 5
EARLY_EC_MAX = 15
EXCLUDE_EC_AUTHORS = {
    "chohlasa",                  # TA account
    "github-actions[bot]",       # built‑in bot
    "auto-commit-bot",           # the figs‑pushing bot
    "dependabot[bot]",
}


# ---------- helpers ----------
def et(dt_str):
    return parser.isoparse(dt_str).astimezone(pytz.timezone("US/Eastern"))

def github_api(url, token):
    r = requests.get(url, headers={"Authorization": f"Bearer {token}",
                                   "Accept": "application/vnd.github+json"})
    r.raise_for_status()
    return r.json()

def pr_metadata():
    ev_path = os.environ["GITHUB_EVENT_PATH"]
    with open(ev_path, "r", encoding="utf‑8") as f:
        data = json.load(f)
    repo = data["repository"]["full_name"]          # e.g. org/repo
    pr_num = data["number"]
    return repo, pr_num

# ---------- grading ----------
def grade_problem1(repo, pr_num, token):
    """30 pts: commits + requested reviewer."""
    commits = github_api(
        f"https://api.github.com/repos/{repo}/pulls/{pr_num}/commits", token)
    authors = {c["author"]["login"] for c in commits if c["author"]}
    commit_pts = 18 if authors else 0

    pr_json = github_api(
        f"https://api.github.com/repos/{repo}/pulls/{pr_num}", token)
    reviewers = {u["login"] for u in pr_json.get("requested_reviewers", [])}
    review_pts = 12 if "chohlasa" in reviewers else 0

    print(f"P1 – authors found: {authors or 'none'}  => {commit_pts}/18")
    print(f"P1 – reviewer ‘chohlasa’ requested? "
          f"{'yes' if review_pts else 'no'}  => {review_pts}/12")
    return commit_pts + review_pts

def grade_problem2(repo_root):
    """40 pts if `run.R` finishes with exit 0."""
    figs = os.path.join(repo_root, "figs")
    
    # 1) Create figs/ if missing
    os.makedirs(figs, exist_ok=True)
    
    # 2) Remove any contents (files/subfolders) inside figs
    for item in os.listdir(figs):
        path = os.path.join(figs, item)
        if os.path.isfile(path) or os.path.islink(path):
            os.remove(path)
        elif os.path.isdir(path):
            shutil.rmtree(path)

    # 3) Run `Rscript run.R`
    res = subprocess.run(["Rscript", "run.R"],
                         cwd=repo_root,
                         capture_output=False, 
                         text=True)

    # 4) Check exit code for success/failure
    if res.returncode == 0:
        print("P2 – run.R executed without error  => 40/40")
        return 40
    else:
        print("P2 – run.R failed")
        return 0

def grade_problem3(readme_path):
    """20 pts if ≥1 figure embed (![](figs/...))."""
    if not os.path.exists(readme_path):
        print("P3 – README.md missing  => 0/20")
        return 0
    txt = open(readme_path, encoding="utf‑8").read()
    if re.search(r"!\[.*?\]\(figs\/[^)]+\)", txt, flags=re.I):
        print("P3 – found at least one figure embed  => 20/20")
        return 20
    print("P3 – no figure embed detected  => 0/20")
    return 0

def grade_problem4(readme_path):
    """10 pts if ≥5 numbered list items (lines starting ‘1.’, ‘2.’ …)."""
    if not os.path.exists(readme_path):
        print("P4 – README.md missing  => 0/10")
        return 0
    lines = open(readme_path, encoding="utf‑8").read().splitlines()
    bullets = [ln for ln in lines if re.match(r"\d+\.\s", ln)]
    if len(bullets) >= 5:
        print(f"P4 – {len(bullets)} numbered bullets  => 10/10")
        return 10
    print(f"P4 – only {len(bullets)} bullets  => 0/10")
    return 0

def extra_credit_early_commits(commits):
    """
    5 pts per distinct day *by a human* before the due date (≤ 15 pts).
    """
    days = {
        et(c["commit"]["committer"]["date"]).strftime("%Y-%m-%d")
        for c in commits
        if c.get("author")                                 # skip anonymous
        and c["author"]["login"] not in EXCLUDE_EC_AUTHORS # skip bots/TA
        and et(c["commit"]["committer"]["date"]).date() < DUE_ET.date()
    }
    pts = EARLY_EC_PER_DAY * min(len(days), EARLY_EC_MAX // EARLY_EC_PER_DAY)
    print(f"Extra credit – early commit days: {sorted(days)} ⇒ +{pts}")
    return pts

# ---------- main ----------
def main():
    token = os.environ.get("GITHUB_TOKEN", "")
    repo_root = "student-code"
    readme = os.path.join(repo_root, "README.md")

    repo, pr_num = pr_metadata()
    all_commits = github_api(
        f"https://api.github.com/repos/{repo}/pulls/{pr_num}/commits", token)

    commit_times = [et(c["commit"]["committer"]["date"]) for c in all_commits]
    last_commit_time = max(commit_times) if commit_times else None
    late = last_commit_time and last_commit_time > DUE_ET
    if last_commit_time:
        print("Last commit:",
              last_commit_time.strftime("%Y‑%m‑%d %H:%M %Z"),
              "(late)" if late else "(on‑time)")

    # ---------- per‑problem grading ----------
    p1 = grade_problem1(repo, pr_num, token)
    p2 = grade_problem2(repo_root)
    p3 = grade_problem3(readme)
    p4 = grade_problem4(readme)
    base = 0 if late else p1 + p2 + p3 + p4

    ec = 0 if late else extra_credit_early_commits(all_commits)
    final = base + ec

    print("\n=== SCORE SUMMARY ===")
    print(f"P1  {p1:>3}/30")
    print(f"P2  {p2:>3}/40")
    print(f"P3  {p3:>3}/20")
    print(f"P4  {p4:>3}/10")
    print(f"Base         {base:>3}/100")
    print(f"Extra credit {ec:>3}  (max 15)")
    print(f"Final score  {final}")

    # red ❌ unless perfect (and on‑time)
    if not late and base < 100:
        sys.exit(1)

if __name__ == "__main__":
    main()
