# Week 5 Box submission

After the final repository is public, create a clean Box submission folder:

```text
Week5_Minimap2/
├── GitHub_repo.txt
├── CHECKSUMS.txt
└── outputs/
```

Example commands:

```bash
mkdir -p Week5_Minimap2/outputs

echo "https://github.com/ArpanPrj/CBC_2026_Week5_Minimap2" \
  > Week5_Minimap2/GitHub_repo.txt

cp results/*.tsv Week5_Minimap2/outputs/
cp results/*.svg Week5_Minimap2/outputs/
cp -r results/pairwise_alignments Week5_Minimap2/outputs/
cp CHECKSUMS.txt Week5_Minimap2/
```

`CHECKSUMS.txt` contains SHA256 hashes for the input/derived data files under `data/` and every scientific result under `results/`.
