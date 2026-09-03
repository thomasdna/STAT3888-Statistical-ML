# CURF CSVs go here

This git package does **not** contain the ABS Basic CURF unit-record files.

They are confidential, some files exceed GitHub's 100 MB limit (`AHSnpa11ba.csv`
is 234 MB), and redistributing them on a public remote would breach the ABS
licence.

## What you need

Copy or symlink every `.csv` from the course `original_data/all_files/`
directory into **this** folder. The dictionaries (`.xls` / `.xlsx`) are already
in the parent `original_data/` directory.

From the repo root, the easiest option is:

```bash
bash setup_data.sh
```

That script looks for CSVs in `../data/original_data/all_files` (this folder
sitting inside `STAT3888/`) and in `~/Desktop/STAT3888/data/original_data/all_files`.

Alternatively set an environment variable and skip the copy:

```bash
export TEAM15_AHS_DATA="$HOME/Desktop/STAT3888/data/original_data"
```

`R/00_setup.R` will then use that path.
