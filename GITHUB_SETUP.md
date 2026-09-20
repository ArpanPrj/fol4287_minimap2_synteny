# Create a separate GitHub repository

Suggested repository name:

```text
CBC_2026_Week5_Minimap2
```

Keep this independent from the previous MUMmer repository.

## Validate first

```bash
bash run_all.sh
cp CHECKSUMS.txt /tmp/CHECKSUMS.minimap.run1.txt
bash run_all.sh
diff -u /tmp/CHECKSUMS.minimap.run1.txt CHECKSUMS.txt
```

If the diff is empty:

```bash
bash scripts/set_reference_checksums.sh
diff -u CHECKSUMS.reference.txt CHECKSUMS.txt
```

On WSL/Linux x86_64, confirm the environment lock exists:

```bash
ls -lh environment-linux-64.lock.txt environment-linux-64.source.sha256
```

## Initialize Git

```bash
git init
git branch -M main
git add .
git status
git commit -m "Add reproducible Minimap2 Fol4287 synteny workflow"
```

Make sure `data/`, `tmp/`, and `logs/` are not staged.

## Create the GitHub repository

Create an empty public repository named:

```text
ArpanPrj/CBC_2026_Week5_Minimap2
```

Do not initialize it with a README, `.gitignore`, or license.

Then:

```bash
git remote add origin https://github.com/ArpanPrj/CBC_2026_Week5_Minimap2.git
git push -u origin main
```

If `origin` already exists:

```bash
git remote set-url origin https://github.com/ArpanPrj/CBC_2026_Week5_Minimap2.git
git push -u origin main
```

The final public repository should contain the scripts/configuration, exact environment lock, `CHECKSUMS.txt`, `CHECKSUMS.reference.txt`, and final `results/`, but not downloaded FASTAs, raw PAF, or logs.
