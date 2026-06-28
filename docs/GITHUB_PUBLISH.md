# Publish this project on GitHub

Guide to create the repository **“AYN sm8550 Easy Kernel Updater for Armbian”** and upload your demo videos.

Suggested repository name (URL slug): **`ayn-sm8550-easy-kernel-updater`**

---

## 1. Prepare the folder locally

From your project directory (e.g. `~/Projects/ayn-sm8550-kernel`):

```bash
cd ~/Projects/ayn-sm8550-kernel

# Copy your two demo clips (rename to match README)
cp /path/to/tuned.mp4    docs/videos/demo-tuned-kernel.mp4
cp /path/to/default.mp4  docs/videos/demo-armbian-default.mp4

# Optional: remove large build artifacts (already in .gitignore)
rm -rf output/ .cache/

# Initialize git if not already
git init
git branch -M main
```

**Do not commit** `output/` or `.cache/` — they are listed in `.gitignore`.

**Include in the repo:**

- `config/golden.config` (~8k lines — required for gaming tuning)
- All scripts, `hooks/`, `lib/`, `config/`
- `docs/`, `LICENSE`, `README.md`

---

## 2. Create the repository on GitHub

### Option A — Web UI

1. Open [https://github.com/new](https://github.com/new)  
2. **Repository name:** `ayn-sm8550-easy-kernel-updater`  
3. **Description:** `Gaming-optimized kernel builder & installer for AYN SM8550 handhelds on Armbian`  
4. **Public** (recommended for sharing)  
5. **Do not** add README, .gitignore, or license (you already have them)  
6. Click **Create repository**

### Option B — GitHub CLI

```bash
gh auth login   # once
gh repo create ayn-sm8550-easy-kernel-updater \
  --public \
  --description "Gaming-optimized kernel builder & installer for AYN SM8550 handhelds on Armbian" \
  --source=. \
  --remote=origin \
  --push
```

If you use Option A, push manually (step 3).

---

## 3. First commit and push

```bash
git add .
git status    # verify: no output/ or .cache/

git commit -m "$(cat <<'EOF'
Initial release: AYN SM8550 easy kernel updater for Armbian.

Interactive build (make_kernel.sh) with golden gaming config, Armbian
patches, ROCKNIX-trimmed firmware, and one-step install (update.sh).
EOF
)"

# Replace YOUR_USER with your GitHub username
git remote add origin git@github.com:YOUR_USER/ayn-sm8550-easy-kernel-updater.git
git push -u origin main
```

HTTPS remote alternative:

```bash
git remote add origin https://github.com/YOUR_USER/ayn-sm8550-easy-kernel-updater.git
```

---

## 4. Embed the demo videos in README

### Method 1 — Files in repo (simple)

Videos in `docs/videos/` are linked from README. GitHub renders MP4 in the file viewer; for inline README playback, use Method 2.

### Method 2 — GitHub-hosted assets (best for README)

1. Open your repo on GitHub → **README.md** → **Edit** (pencil)  
2. Drag each MP4 into the editor where you want it  
3. GitHub uploads to `https://github.com/user-attachments/assets/...`  
4. Replace the `PLACEHOLDER` URLs in README with the generated links  
5. Commit **Update README with demo videos**

### Method 3 — YouTube (optional)

Upload both clips (or one side-by-side comparison), embed:

```markdown
[![Performance comparison](https://img.youtube.com/vi/VIDEO_ID/0.jpg)](https://www.youtube.com/watch?v=VIDEO_ID)
```

---

## 5. Repository settings (recommended)

| Setting | Value |
|---------|--------|
| **About → Website** | optional link to AYN / Armbian wiki |
| **Topics** | `armbian`, `ayn`, `odin2`, `sm8550`, `kernel`, `gaming`, `handheld` |
| **Releases** | optional: tag `v1.0.0` with notes (no binaries required — users build on device) |

Add topics on the repo home page (gear icon next to About):

```
armbian ayn odin2 sm8550 snapdragon kernel gaming handheld linux
```

---

## 6. Update README placeholders

After the repo exists, search-replace in `README.md`:

| Placeholder | Replace with |
|-------------|--------------|
| `YOUR_USER` | your GitHub username |
| `YOUR_REPO` | `ayn-sm8550-easy-kernel-updater` |
| `PLACEHOLDER` video URLs | GitHub asset URLs from step 4 |

```bash
sed -i 's/YOUR_USER/myusername/g' README.md
sed -i 's/YOUR_REPO/ayn-sm8550-easy-kernel-updater/g' README.md
git add README.md && git commit -m "docs: fix clone URLs and video links" && git push
```

---

## 7. Optional: GitHub Release checklist

```bash
git tag -a v1.0.0 -m "First public release"
git push origin v1.0.0
```

On GitHub → **Releases → Draft new release**:

- **Tag:** `v1.0.0`  
- **Title:** `v1.0.0 — Easy kernel updater for AYN SM8550`  
- **Body:** copy Performance summary + Quick start from README  
- Attach demo videos as release assets if not embedded in README  

---

## 8. What users clone and run

Share this one-liner in videos / social:

```bash
git clone https://github.com/YOUR_USER/ayn-sm8550-easy-kernel-updater.git
cd ayn-sm8550-easy-kernel-updater
./make_kernel.sh && ./update.sh
```

---

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `golden.config` missing after clone | Ensure it was committed (`git ls-files config/golden.config`) |
| Push rejected (large file) | Remove `output/` or `.cache/` from git history; keep videos under ~25 MB each or use YouTube |
| SSH permission denied | Use HTTPS remote or add SSH key in GitHub Settings → SSH keys |

---

## File checklist before push

- [ ] `README.md` — English, videos linked  
- [ ] `LICENSE` — MIT  
- [ ] `.gitignore` — `output/`, `.cache/`  
- [ ] `docs/PERFORMANCE.md` — technical explanation  
- [ ] `docs/SOURCES.md` — upstream attribution  
- [ ] `docs/videos/demo-*.mp4` — both demos (optional in git if using GitHub asset upload)  
- [ ] `config/golden.config` — present  
- [ ] `make_kernel.sh` + `update.sh` — executable (`chmod +x *.sh scripts/*.sh hooks/*`)

```bash
chmod +x make_kernel.sh update.sh install-from-output.sh scripts/*.sh hooks/*
```
