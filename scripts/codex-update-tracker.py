#!/usr/bin/env python3
"""
Update docs/codex/CODEX_TRACKER.xlsx status fields for a prompt ID.

This script edits the Tracker sheet directly (no external dependencies).
It can optionally verify that a PR is merged before marking an ID complete.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import subprocess
import sys
import zipfile
from pathlib import Path
from typing import Dict, Optional
import xml.etree.ElementTree as ET


NS = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
REL_NS = "http://schemas.openxmlformats.org/package/2006/relationships"
DOC_REL_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"


def run(cmd: list[str]) -> str:
    proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if proc.returncode != 0:
        raise RuntimeError(f"command failed: {' '.join(cmd)}\n{proc.stderr.strip()}")
    return proc.stdout


def col_to_num(col: str) -> int:
    n = 0
    for ch in col:
        n = n * 26 + (ord(ch) - ord("A") + 1)
    return n


def num_to_col(num: int) -> str:
    out = []
    while num > 0:
        num, rem = divmod(num - 1, 26)
        out.append(chr(ord("A") + rem))
    return "".join(reversed(out))


def cell_parts(ref: str) -> tuple[str, int]:
    col = "".join(ch for ch in ref if ch.isalpha())
    row = int("".join(ch for ch in ref if ch.isdigit()))
    return col, row


def get_cell_text(cell: ET.Element) -> str:
    t = cell.attrib.get("t")
    if t == "inlineStr":
        isel = cell.find("m:is", NS)
        if isel is None:
            return ""
        return "".join((tn.text or "") for tn in isel.findall(".//m:t", NS))
    v = cell.find("m:v", NS)
    return "" if v is None else (v.text or "")


def set_inline_text(cell: ET.Element, text: str) -> None:
    cell.attrib["t"] = "inlineStr"
    for child in list(cell):
        cell.remove(child)
    isel = ET.SubElement(cell, f"{{{NS['m']}}}is")
    tn = ET.SubElement(isel, f"{{{NS['m']}}}t")
    tn.text = text


def ensure_cell(row_el: ET.Element, col: str, row_num: int) -> ET.Element:
    target_ref = f"{col}{row_num}"
    cells = row_el.findall("m:c", NS)
    for c in cells:
        if c.attrib.get("r") == target_ref:
            return c

    new_cell = ET.Element(f"{{{NS['m']}}}c", {"r": target_ref, "t": "inlineStr"})
    # Preserve ordering by column index.
    target_num = col_to_num(col)
    inserted = False
    for idx, c in enumerate(cells):
        cref = c.attrib.get("r", "")
        ccol, _ = cell_parts(cref)
        if col_to_num(ccol) > target_num:
            row_el.insert(idx, new_cell)
            inserted = True
            break
    if not inserted:
        row_el.append(new_cell)
    return new_cell


def find_cell(row_el: ET.Element, col: str) -> Optional[ET.Element]:
    for c in row_el.findall("m:c", NS):
        cref = c.attrib.get("r", "")
        ccol, _ = cell_parts(cref)
        if ccol == col:
            return c
    return None


def find_row_by_col_a(sheet_xml: ET.Element, value: str) -> Optional[ET.Element]:
    rows = sheet_xml.findall("m:sheetData/m:row", NS)
    for row in rows:
        a_cell = find_cell(row, "A")
        if a_cell is not None and get_cell_text(a_cell).strip() == value:
            return row
    return None


def ensure_kv_row(sheet_xml: ET.Element, field: str) -> ET.Element:
    existing = find_row_by_col_a(sheet_xml, field)
    if existing is not None:
        return existing

    sheet_data = sheet_xml.find("m:sheetData", NS)
    if sheet_data is None:
        raise RuntimeError("invalid worksheet: missing sheetData")

    rows = sheet_data.findall("m:row", NS)
    max_row_num = max((int(r.attrib.get("r", "0")) for r in rows), default=0)
    next_row_num = max_row_num + 1

    row_el = ET.SubElement(sheet_data, f"{{{NS['m']}}}row", {"r": str(next_row_num)})
    field_cell = ensure_cell(row_el, "A", next_row_num)
    set_inline_text(field_cell, field)
    ensure_cell(row_el, "B", next_row_num)
    return row_el


def detect_tracker_pr_column(tracker_sheet_xml: ET.Element) -> str:
    header_row = find_row_by_col_a(tracker_sheet_xml, "ID")
    if header_row is None:
        return "T"

    for cell in header_row.findall("m:c", NS):
        col, _ = cell_parts(cell.attrib.get("r", ""))
        if get_cell_text(cell).strip() == "PR #":
            return col
    return "T"


def pr_is_merged(pr: int, repo: str) -> tuple[bool, str]:
    out = run(["gh", "pr", "view", str(pr), "--repo", repo, "--json", "number,state,mergedAt,title,url"])
    data = json.loads(out)
    merged_at = data.get("mergedAt")
    if merged_at:
        return True, f"PR #{pr} merged ({data.get('url')})"
    return False, f"PR #{pr} is not merged (state={data.get('state')})"


def update_tracks_md(
    tracks_path: Path,
    prompt_id: str,
    status: str,
    winner: Optional[str],
    log_file: Optional[str],
    review_file: Optional[str],
    notes: Optional[str],
) -> bool:
    text = tracks_path.read_text(encoding="utf-8")
    lines = text.splitlines()
    updated = False
    in_status_tracker = False

    for idx, line in enumerate(lines):
        if line.strip() == "## Status Tracker":
            in_status_tracker = True
            continue
        if in_status_tracker and line.startswith("## "):
            break
        if not in_status_tracker:
            continue
        if not line.startswith(f"| {prompt_id} |"):
            continue
        parts = [p.strip() for p in line.split("|")]
        # Normalize malformed rows that accidentally have extra columns.
        # Expected shape: ['', Prompt, A/B, Status, Winner, Log, Review, Notes, '']
        if len(parts) > 9:
            merged_notes = " | ".join(p for p in parts[7:-1] if p)
            parts = parts[:7] + [merged_notes, ""]
        if len(parts) < 9:
            continue
        parts[3] = status
        if winner is not None:
            parts[4] = winner
        if log_file is not None:
            parts[5] = log_file
        if review_file is not None:
            parts[6] = review_file
        if notes is not None:
            parts[7] = notes
        lines[idx] = "| " + " | ".join(parts[1:-1]) + " |"
        updated = True
        break

    if updated:
        tracks_path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    return updated


def main() -> int:
    parser = argparse.ArgumentParser(description="Update CODEX tracker row for a prompt ID")
    parser.add_argument("--id", required=True, help="Prompt ID (e.g., C0, A0, B1)")
    parser.add_argument("--status", default="✅ Merged", help="Tracker status text")
    parser.add_argument("--winner", default=None, help="Winner value")
    parser.add_argument("--log-file", default=None, help="Log file path")
    parser.add_argument("--review-file", default=None, help="Review file path")
    parser.add_argument("--notes", default=None, help="Notes text")
    parser.add_argument("--date-done", default=dt.date.today().isoformat(), help="Date done (YYYY-MM-DD)")
    parser.add_argument("--tracker", default="docs/codex/CODEX_TRACKER.xlsx", help="Path to CODEX_TRACKER.xlsx")
    parser.add_argument("--update-xlsx", action="store_true", help="Also update CODEX_TRACKER.xlsx row")
    parser.add_argument("--closeout", action="store_true", help="Close out an ID (sets merged status, PR #, and completion dates)")
    parser.add_argument("--pr", type=int, default=None, help="PR number to verify merged state")
    parser.add_argument("--pr-number", type=int, default=None, help="PR number to record in tracker and ID sheet")
    parser.add_argument("--repo", default=None, help="owner/repo for --pr checks")
    parser.add_argument("--update-tracks-md", action="store_true", help="Also update docs/codex/tracks.md row")
    args = parser.parse_args()

    if args.closeout:
        args.status = "✅ Merged"
        args.update_xlsx = True

    tracked_pr = args.pr_number if args.pr_number is not None else args.pr
    if args.closeout and tracked_pr is None:
        print("ERROR: --closeout requires --pr or --pr-number", file=sys.stderr)
        return 1

    if args.pr is not None:
        if not args.repo:
            print("ERROR: --repo owner/repo is required when using --pr", file=sys.stderr)
            return 1
        merged, msg = pr_is_merged(args.pr, args.repo)
        print(msg)
        if not merged:
            print("ERROR: refusing to mark complete because PR is not merged", file=sys.stderr)
            return 1

    tracker_path = Path(args.tracker)
    contents: Dict[str, bytes] = {}
    workbook_xml = None
    tracker_sheet_xml = None
    tracker_sheet_target = None
    id_sheet_xml = None
    id_sheet_target = None
    tracker_row = None
    tracker_row_num = None
    pr_col = "T"
    before_sheet_count = 0
    before_worksheet_file_count = 0
    if args.update_xlsx:
        if not tracker_path.exists():
            print(f"ERROR: tracker not found: {tracker_path}", file=sys.stderr)
            return 1

        with zipfile.ZipFile(tracker_path, "r") as zin:
            contents = {name: zin.read(name) for name in zin.namelist()}
        before_worksheet_file_count = sum(1 for n in contents if n.startswith("xl/worksheets/"))

        wb = ET.fromstring(contents["xl/workbook.xml"])
        workbook_xml = wb
        before_sheet_count = len(wb.findall("m:sheets/m:sheet", NS))
        rels = ET.fromstring(contents["xl/_rels/workbook.xml.rels"])
        rid_to_target = {
            rel.attrib["Id"]: rel.attrib["Target"].lstrip("/")
            for rel in rels.findall(f"{{{REL_NS}}}Relationship")
        }

        for sheet in wb.findall("m:sheets/m:sheet", NS):
            if sheet.attrib.get("name") == "Tracker":
                rid = sheet.attrib.get(f"{{{DOC_REL_NS}}}id")
                if rid is not None:
                    tracker_sheet_target = rid_to_target.get(rid)
            if sheet.attrib.get("name") == f"ID-{args.id}":
                rid = sheet.attrib.get(f"{{{DOC_REL_NS}}}id")
                if rid is not None:
                    id_sheet_target = rid_to_target.get(rid)
                break
        if not tracker_sheet_target:
            print("ERROR: could not locate Tracker worksheet", file=sys.stderr)
            return 1

        tracker_sheet_xml = ET.fromstring(contents[tracker_sheet_target])
        tracker_row = find_row_by_col_a(tracker_sheet_xml, args.id)
        if tracker_row is None:
            print(f"ERROR: prompt ID {args.id} not found in Tracker sheet", file=sys.stderr)
            return 1
        tracker_row_num = int(tracker_row.attrib["r"])
        pr_col = detect_tracker_pr_column(tracker_sheet_xml)
        header_row = find_row_by_col_a(tracker_sheet_xml, "ID")
        if header_row is not None:
            header_row_num = int(header_row.attrib["r"])
            pr_header_cell = ensure_cell(header_row, pr_col, header_row_num)
            set_inline_text(pr_header_cell, "PR #")

        if id_sheet_target is not None:
            id_sheet_xml = ET.fromstring(contents[id_sheet_target])

    if args.update_xlsx:
        if tracker_sheet_xml is None or tracker_row is None or tracker_row_num is None or tracker_sheet_target is None:
            print("ERROR: internal tracker state incomplete; refusing to write", file=sys.stderr)
            return 1

        # Column mapping in Tracker sheet:
        # L status, M winner, N log, O review, Q date done, R notes, T PR #.
        updates = {
            "L": args.status,
            "M": args.winner,
            "N": args.log_file,
            "O": args.review_file,
            "Q": args.date_done,
            "R": args.notes,
        }
        if tracked_pr is not None:
            updates[pr_col] = str(tracked_pr)

        for col, val in updates.items():
            if val is None:
                continue
            cell = ensure_cell(tracker_row, col, tracker_row_num)
            set_inline_text(cell, str(val))

        if id_sheet_xml is not None and tracked_pr is not None:
            status_row = ensure_kv_row(id_sheet_xml, "Status")
            set_inline_text(ensure_cell(status_row, "B", int(status_row.attrib["r"])), args.status)

            if args.winner is not None:
                winner_row = ensure_kv_row(id_sheet_xml, "Winner")
                set_inline_text(ensure_cell(winner_row, "B", int(winner_row.attrib["r"])), args.winner)

            pr_row = ensure_kv_row(id_sheet_xml, "PR #")
            set_inline_text(ensure_cell(pr_row, "B", int(pr_row.attrib["r"])), str(tracked_pr))

            date_completed_row = ensure_kv_row(id_sheet_xml, "Date Completed")
            set_inline_text(
                ensure_cell(date_completed_row, "B", int(date_completed_row.attrib["r"])),
                args.date_done,
            )

            if args.closeout:
                pending_row = ensure_kv_row(id_sheet_xml, "Pending")
                summary = f"Completed: merged via PR #{tracked_pr} on {args.date_done}"
                set_inline_text(ensure_cell(pending_row, "B", int(pending_row.attrib["r"])), summary)

        contents[tracker_sheet_target] = ET.tostring(tracker_sheet_xml, encoding="utf-8", xml_declaration=True)
        if id_sheet_xml is not None and id_sheet_target is not None:
            contents[id_sheet_target] = ET.tostring(id_sheet_xml, encoding="utf-8", xml_declaration=True)
        if workbook_xml is not None:
            contents["xl/workbook.xml"] = ET.tostring(workbook_xml, encoding="utf-8", xml_declaration=True)

        tmp = tracker_path.with_suffix(tracker_path.suffix + ".tmp")
        with zipfile.ZipFile(tmp, "w", compression=zipfile.ZIP_DEFLATED) as zout:
            for name, data in contents.items():
                zout.writestr(name, data)

        # Safety checks: preserve sheet/workbook structure before replacing.
        with zipfile.ZipFile(tmp, "r") as zcheck:
            after_worksheet_file_count = sum(1 for n in zcheck.namelist() if n.startswith("xl/worksheets/"))
            wb_after = ET.fromstring(zcheck.read("xl/workbook.xml"))
            after_sheet_count = len(wb_after.findall("m:sheets/m:sheet", NS))
        if after_worksheet_file_count != before_worksheet_file_count or after_sheet_count != before_sheet_count:
            tmp.unlink(missing_ok=True)
            print("ERROR: workbook structure check failed; refusing to replace tracker file", file=sys.stderr)
            return 1

        tmp.replace(tracker_path)

        print(f"Updated tracker row {args.id} in {tracker_path}")
        if id_sheet_xml is None:
            print(f"WARN: ID-{args.id} worksheet not found; skipped ID-sheet updates")
        else:
            print(f"Updated ID-{args.id} worksheet metadata")
    else:
        print("Skipped CODEX_TRACKER.xlsx update (use --update-xlsx to enable)")

    if args.update_tracks_md:
        tracks_path = Path("docs/codex/tracks.md")
        if tracks_path.exists():
            changed = update_tracks_md(
                tracks_path=tracks_path,
                prompt_id=args.id,
                status=args.status,
                winner=args.winner,
                log_file=args.log_file,
                review_file=args.review_file,
                notes=args.notes,
            )
            if changed:
                print(f"Updated markdown tracker row {args.id} in {tracks_path}")
            else:
                print(f"WARN: could not update markdown tracker row for {args.id}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
