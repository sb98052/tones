#!/usr/bin/env python3
import argparse, csv, sys
from datetime import datetime

COMMON_DATE_FORMATS = [
    "%Y-%m-%d",     # 2023-07-14
    "%m/%d/%Y",     # 07/14/2023
    "%d/%m/%Y",     # 14/07/2023
    "%Y/%m/%d",     # 2023/07/14
    "%d-%b-%Y",     # 14-Jul-2023
    "%b %d, %Y",    # Jul 14, 2023
]

def parse_args():
    p = argparse.ArgumentParser(description="CSV -> Pine arrays (DATES, VALUES)")
    p.add_argument("csvfile", help="Input CSV file path")
    p.add_argument("--date-col", required=True,
                   help="Date column name or 0-based index (e.g., Date or 0)")
    p.add_argument("--value-col", required=True,
                   help="Value column name or 0-based index (e.g., Value or 1)")
    p.add_argument("--delimiter", default=",", help="CSV delimiter (default ,)")
    p.add_argument("--round", type=int, default=None, dest="rnd",
                   help="Round values to N decimals")
    p.add_argument("--skip-blank", action="store_true",
                   help="Skip rows with blank/NaN values (default: yes); kept for symmetry")
    return p.parse_args()

def to_index(header, col_spec):
    """Map a name or index string to an integer index."""
    try:
        idx = int(col_spec)
        if idx < 0 or idx >= len(header):
            raise ValueError
        return idx
    except ValueError:
        # treat as name
        if col_spec in header:
            return header.index(col_spec)
        # case-insensitive fallback
        lowered = [h.lower() for h in header]
        if col_spec.lower() in lowered:
            return lowered.index(col_spec.lower())
        raise SystemExit(f"Column '{col_spec}' not found in header: {header}")

def try_parse_date(s):
    s = s.strip()
    if not s:
        return None
    # ISO 8601 fast path
    try:
        # datetime.fromisoformat handles YYYY-MM-DD
        dt = datetime.fromisoformat(s.split("T")[0])
        return dt
    except Exception:
        pass
    for fmt in COMMON_DATE_FORMATS:
        try:
            return datetime.strptime(s, fmt)
        except Exception:
            continue
    return None

def try_parse_float(s):
    s = s.strip()
    if s == "" or s.lower() in {"na", "nan", "null"}:
        return None
    # allow percentages like "57.8%"
    if s.endswith("%"):
        try:
            return float(s[:-1]) / 100.0
        except Exception:
            return None
    try:
        return float(s.replace(",", ""))  # allow thousand-separators
    except Exception:
        return None

def read_rows(path, delimiter):
    with open(path, "r", newline="", encoding="utf-8-sig") as f:
        sniffer = csv.Sniffer()
        sample = f.read(4096)
        f.seek(0)
        has_header = sniffer.has_header(sample)
        reader = csv.reader(f, delimiter=delimiter)
        header = next(reader) if has_header else None
        rows = list(reader)
    return header, rows

def main():
    a = parse_args()
    header, rows = read_rows(a.csvfile, a.delimiter)
    if header is None:
        # synthesize header by index
        first_row_len = len(rows[0]) if rows else 0
        header = [f"col{i}" for i in range(first_row_len)]

    d_idx = to_index(header, a.date_col)
    v_idx = to_index(header, a.value_col)

    # Collect parsed tuples
    pairs = []
    for r in rows:
        if max(d_idx, v_idx) >= len(r):
            continue
        ds, vs = r[d_idx], r[v_idx]
        dt = try_parse_date(ds)
        val = try_parse_float(vs)
        if dt is None or val is None:
            continue
        if a.rnd is not None:
            val = round(val, a.rnd)
        pairs.append((dt, val))

    if not pairs:
        sys.exit("No valid (date, value) pairs parsed. Check columns and formats.")

    # De-duplicate by date (keep last occurrence), then sort ascending
    dedup = {}
    for dt, val in pairs:
        dedup[dt.date()] = val
    items = sorted(dedup.items(), key=lambda kv: kv[0])  # [(date, value), ...]

    # Build Pine array literals
    dates_literals = ', '.join(f"\"{d.isoformat()}\"" for d, _ in items)
    values_literals = ', '.join(
        (f"{v:.{a.rnd}f}" if a.rnd is not None else repr(v)) for _, v in items
    )

    # Emit the snippet
    print("// ---- BEGIN: paste into your Pine script ----")
    print("var string[] DATES = array.from(")
    print(f"    {dates_literals}")
    print(")")
    print("var float[] VALUES = array.from(")
    print(f"    {values_literals}")
    print(")")
    print("// ---- END ----")
    print(f"// Count: {len(items)} points")

if __name__ == "__main__":
    main()

