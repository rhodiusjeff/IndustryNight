#!/usr/bin/env python3
"""
Industry Night — Executive Brief PowerPoint Generator

Generates a professional .pptx presentation from project data.
Re-run this script to regenerate the deck with updated metrics.

Usage:
    source /tmp/pptx-env/bin/activate
    python3 scripts/generate-exec-brief.py
"""

from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN, MSO_ANCHOR
from pptx.enum.shapes import MSO_SHAPE
from datetime import date

# ─── Brand Colors ───────────────────────────────────────────────────────────
BLACK       = RGBColor(0x0F, 0x0F, 0x0F)
DARK_BG     = RGBColor(0x1A, 0x1A, 0x2E)
ACCENT      = RGBColor(0x6C, 0x5C, 0xE7)   # Purple accent
ACCENT_LIGHT= RGBColor(0xA2, 0x96, 0xF0)
WHITE       = RGBColor(0xFF, 0xFF, 0xFF)
LIGHT_GRAY  = RGBColor(0xCC, 0xCC, 0xCC)
MID_GRAY    = RGBColor(0x88, 0x88, 0x99)
GREEN       = RGBColor(0x00, 0xB8, 0x94)
AMBER       = RGBColor(0xFD, 0xCB, 0x6E)
RED_SOFT    = RGBColor(0xE1, 0x7A, 0x7A)
CARD_BG     = RGBColor(0x22, 0x22, 0x3A)
SLIDE_BG    = RGBColor(0x12, 0x12, 0x22)

# ─── Report Data (update these for weekly refresh) ──────────────────────────
REPORT_DATE = date.today().strftime("%B %d, %Y")
PERIOD      = "Project Inception through Week 2"

# ─── Helpers ────────────────────────────────────────────────────────────────

def set_slide_bg(slide, color):
    bg = slide.background
    fill = bg.fill
    fill.solid()
    fill.fore_color.rgb = color

def add_textbox(slide, left, top, width, height):
    return slide.shapes.add_textbox(left, top, width, height)

def set_text(tf, text, size=18, color=WHITE, bold=False, alignment=PP_ALIGN.LEFT, font_name="Calibri"):
    tf.clear()
    tf.word_wrap = True
    p = tf.paragraphs[0]
    p.text = text
    p.font.size = Pt(size)
    p.font.color.rgb = color
    p.font.bold = bold
    p.font.name = font_name
    p.alignment = alignment
    return p

def add_para(tf, text, size=14, color=WHITE, bold=False, space_before=Pt(4), space_after=Pt(2), alignment=PP_ALIGN.LEFT, font_name="Calibri"):
    p = tf.add_paragraph()
    p.text = text
    p.font.size = Pt(size)
    p.font.color.rgb = color
    p.font.bold = bold
    p.font.name = font_name
    p.space_before = space_before
    p.space_after = space_after
    p.alignment = alignment
    return p

def add_bullet(tf, text, size=14, color=WHITE, level=0, bold=False, font_name="Calibri"):
    p = tf.add_paragraph()
    p.text = text
    p.font.size = Pt(size)
    p.font.color.rgb = color
    p.font.bold = bold
    p.font.name = font_name
    p.level = level
    p.space_before = Pt(3)
    p.space_after = Pt(2)
    return p

def add_rounded_rect(slide, left, top, width, height, fill_color=CARD_BG):
    shape = slide.shapes.add_shape(MSO_SHAPE.ROUNDED_RECTANGLE, left, top, width, height)
    shape.fill.solid()
    shape.fill.fore_color.rgb = fill_color
    shape.line.fill.background()
    shape.shadow.inherit = False
    return shape

def add_stat_card(slide, left, top, number, label, accent_color=ACCENT):
    card = add_rounded_rect(slide, left, top, Inches(2.1), Inches(1.2))
    tf = card.text_frame
    tf.margin_top = Inches(0.15)
    tf.margin_left = Inches(0.15)
    tf.word_wrap = True
    set_text(tf, number, size=32, color=accent_color, bold=True)
    add_para(tf, label, size=11, color=LIGHT_GRAY, space_before=Pt(0))

def add_accent_line(slide, top):
    line = slide.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(0.6), top, Inches(1.5), Pt(3))
    line.fill.solid()
    line.fill.fore_color.rgb = ACCENT
    line.line.fill.background()

def slide_title(slide, title, subtitle=None):
    set_slide_bg(slide, SLIDE_BG)
    add_accent_line(slide, Inches(0.5))
    tb = add_textbox(slide, Inches(0.6), Inches(0.6), Inches(8.5), Inches(0.6))
    set_text(tb.text_frame, title, size=28, color=WHITE, bold=True)
    if subtitle:
        tb2 = add_textbox(slide, Inches(0.6), Inches(1.15), Inches(8.5), Inches(0.35))
        set_text(tb2.text_frame, subtitle, size=13, color=MID_GRAY)


def add_table_slide(slide, title, headers, rows, col_widths=None, subtitle=None):
    """Add a styled table to a slide."""
    slide_title(slide, title, subtitle)

    num_rows = len(rows) + 1
    num_cols = len(headers)
    top = Inches(1.65) if subtitle else Inches(1.45)
    table_shape = slide.shapes.add_table(num_rows, num_cols, Inches(0.6), top, Inches(8.8), Inches(0.35 * num_rows))
    table = table_shape.table

    if col_widths:
        for i, w in enumerate(col_widths):
            table.columns[i].width = Inches(w)

    # Header row
    for i, h in enumerate(headers):
        cell = table.cell(0, i)
        cell.text = h
        cell.fill.solid()
        cell.fill.fore_color.rgb = ACCENT
        for p in cell.text_frame.paragraphs:
            p.font.size = Pt(11)
            p.font.color.rgb = WHITE
            p.font.bold = True
            p.font.name = "Calibri"

    # Data rows
    for r_idx, row in enumerate(rows):
        for c_idx, val in enumerate(row):
            cell = table.cell(r_idx + 1, c_idx)
            cell.text = str(val)
            cell.fill.solid()
            cell.fill.fore_color.rgb = CARD_BG if r_idx % 2 == 0 else SLIDE_BG
            for p in cell.text_frame.paragraphs:
                p.font.size = Pt(11)
                p.font.color.rgb = WHITE
                p.font.name = "Calibri"


# ─── Presentation ───────────────────────────────────────────────────────────

prs = Presentation()
prs.slide_width = Inches(13.333)
prs.slide_height = Inches(7.5)


# ━━━ SLIDE 1: Title ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
sl = prs.slides.add_slide(prs.slide_layouts[6])  # blank
set_slide_bg(sl, SLIDE_BG)

# Big accent bar
bar = sl.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(0), Inches(0), Inches(0.15), Inches(7.5))
bar.fill.solid()
bar.fill.fore_color.rgb = ACCENT
bar.line.fill.background()

# Title
tb = add_textbox(sl, Inches(1.0), Inches(1.8), Inches(10), Inches(1.2))
set_text(tb.text_frame, "INDUSTRY NIGHT", size=52, color=WHITE, bold=True)
add_para(tb.text_frame, "Executive Brief", size=28, color=ACCENT_LIGHT, bold=False, space_before=Pt(8))

# Divider line
line = sl.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(1.0), Inches(3.7), Inches(4), Pt(2))
line.fill.solid()
line.fill.fore_color.rgb = ACCENT
line.line.fill.background()

# Subtitle info
tb2 = add_textbox(sl, Inches(1.0), Inches(4.0), Inches(10), Inches(1.5))
set_text(tb2.text_frame, REPORT_DATE, size=16, color=LIGHT_GRAY)
add_para(tb2.text_frame, PERIOD, size=14, color=MID_GRAY, space_before=Pt(8))
add_para(tb2.text_frame, "Confidential", size=12, color=MID_GRAY, space_before=Pt(20))


# ━━━ SLIDE 2: What Is Industry Night? ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
sl = prs.slides.add_slide(prs.slide_layouts[6])
slide_title(sl, "What Is Industry Night?", "Platform for creative professionals in NYC")

# Left column — description
tb = add_textbox(sl, Inches(0.6), Inches(1.6), Inches(5.5), Inches(4.5))
tf = tb.text_frame
tf.word_wrap = True
set_text(tf, "The Problem", size=18, color=ACCENT_LIGHT, bold=True)
add_bullet(tf, "Creative professionals (stylists, makeup artists, photographers, videographers) lack a purpose-built networking platform", size=13, color=LIGHT_GRAY)
add_bullet(tf, "Existing tools are generic (Meetup, Eventbrite) or portfolio-focused (Behance)", size=13, color=LIGHT_GRAY)
add_bullet(tf, "No platform ties event attendance to verified community membership", size=13, color=LIGHT_GRAY)
add_para(tf, "", size=6, color=WHITE)
add_para(tf, "The Solution", size=18, color=ACCENT_LIGHT, bold=True)
add_bullet(tf, "Invite-only community tied to real-world event attendance", size=13, color=LIGHT_GRAY)
add_bullet(tf, "QR-code networking at events creates instant, mutual connections", size=13, color=LIGHT_GRAY)
add_bullet(tf, "Verification through attendance builds trust and authenticity", size=13, color=LIGHT_GRAY)
add_bullet(tf, "Two apps: Social (for creatives) + Admin (for operators)", size=13, color=LIGHT_GRAY)

# Right column — two product cards
card1 = add_rounded_rect(sl, Inches(6.8), Inches(1.6), Inches(5.8), Inches(2.2))
tf1 = card1.text_frame
tf1.margin_top = Inches(0.2)
tf1.margin_left = Inches(0.25)
tf1.word_wrap = True
set_text(tf1, "Social App", size=18, color=ACCENT_LIGHT, bold=True)
add_para(tf1, "Target:  Creative professionals", size=12, color=LIGHT_GRAY)
add_para(tf1, "Platforms:  iOS, Android, Web", size=12, color=LIGHT_GRAY)
add_para(tf1, "Purpose:  Attend events, QR networking, community feed, perks", size=12, color=LIGHT_GRAY)

card2 = add_rounded_rect(sl, Inches(6.8), Inches(4.1), Inches(5.8), Inches(2.2))
tf2 = card2.text_frame
tf2.margin_top = Inches(0.2)
tf2.margin_left = Inches(0.25)
tf2.word_wrap = True
set_text(tf2, "Admin App", size=18, color=ACCENT_LIGHT, bold=True)
add_para(tf2, "Target:  Platform operators", size=12, color=LIGHT_GRAY)
add_para(tf2, "Platforms:  Web, iOS, Android", size=12, color=LIGHT_GRAY)
add_para(tf2, "Purpose:  Manage events, users, sponsors, moderation", size=12, color=LIGHT_GRAY)


# ━━━ SLIDE 3: How It Works ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
sl = prs.slides.add_slide(prs.slide_layouts[6])
slide_title(sl, "How It Works", "Ticket purchase to verified community member")

steps = [
    ("1", "Buy Ticket", "User purchases on\nPosh.vip", "Webhook creates\nuser record"),
    ("2", "Download App", "SMS login\n(phone-based)", "Set up profile\n& specialties"),
    ("3", "Attend Event", "Door staff gives\n4-digit activation code", "User enters code\nin app"),
    ("4", "Connect & Verify", "Scan QR codes to\nmake connections", "First connection =\nVerified status"),
    ("5", "Full Access", "Community board,\nsponsor perks", "Networking at\nfuture events"),
]

for i, (num, title, line1, line2) in enumerate(steps):
    left = Inches(0.6 + i * 2.5)
    # Step number circle
    circle = sl.shapes.add_shape(MSO_SHAPE.OVAL, left + Inches(0.75), Inches(1.7), Inches(0.55), Inches(0.55))
    circle.fill.solid()
    circle.fill.fore_color.rgb = ACCENT
    circle.line.fill.background()
    ctf = circle.text_frame
    ctf.margin_top = Inches(0.0)
    ctf.margin_bottom = Inches(0.0)
    ctf.vertical_anchor = MSO_ANCHOR.MIDDLE
    set_text(ctf, num, size=20, color=WHITE, bold=True, alignment=PP_ALIGN.CENTER)

    # Connector line (except last)
    if i < 4:
        conn = sl.shapes.add_shape(MSO_SHAPE.RECTANGLE, left + Inches(1.35), Inches(1.95), Inches(1.9), Pt(2))
        conn.fill.solid()
        conn.fill.fore_color.rgb = ACCENT
        conn.line.fill.background()

    # Step title
    tb = add_textbox(sl, left, Inches(2.4), Inches(2.2), Inches(0.4))
    set_text(tb.text_frame, title, size=16, color=WHITE, bold=True, alignment=PP_ALIGN.CENTER)

    # Card
    card = add_rounded_rect(sl, left, Inches(2.9), Inches(2.2), Inches(1.8))
    ctf = card.text_frame
    ctf.margin_top = Inches(0.2)
    ctf.margin_left = Inches(0.15)
    ctf.word_wrap = True
    set_text(ctf, line1, size=12, color=LIGHT_GRAY, alignment=PP_ALIGN.CENTER)
    add_para(ctf, "", size=6, color=WHITE)
    add_para(ctf, line2, size=12, color=LIGHT_GRAY, alignment=PP_ALIGN.CENTER)


# ━━━ SLIDE 4: Project Timeline ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
sl = prs.slides.add_slide(prs.slide_layouts[6])
slide_title(sl, "Project Timeline", "12 days from first commit to foundation complete")

milestones = [
    ("Feb 4", "Requirements\nFinalized", "Product requirements\ndocument v1.8\ncompleted"),
    ("Feb 13", "Initial\nCommit", "Project scaffolded,\nmonorepo structure\nestablished"),
    ("Feb 23", "Infrastructure\nLaydown", "AWS EKS, domain\nmigration, ops\ntooling, DB scripts"),
    ("Feb 25", "PR #1\nMerged", "Foundation complete,\nadmin auth branch\nin progress"),
]

# Timeline line
line = sl.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(1.0), Inches(3.6), Inches(11.0), Pt(3))
line.fill.solid()
line.fill.fore_color.rgb = ACCENT
line.line.fill.background()

for i, (dt, title, desc) in enumerate(milestones):
    cx = Inches(1.5 + i * 3.0)
    # Dot
    dot = sl.shapes.add_shape(MSO_SHAPE.OVAL, cx + Inches(0.5), Inches(3.45), Inches(0.35), Inches(0.35))
    dot.fill.solid()
    dot.fill.fore_color.rgb = ACCENT
    dot.line.fill.background()
    # Date above
    tb = add_textbox(sl, cx - Inches(0.2), Inches(2.3), Inches(1.8), Inches(0.35))
    set_text(tb.text_frame, dt, size=14, color=ACCENT_LIGHT, bold=True, alignment=PP_ALIGN.CENTER)
    # Title
    tb = add_textbox(sl, cx - Inches(0.2), Inches(2.65), Inches(1.8), Inches(0.7))
    set_text(tb.text_frame, title, size=14, color=WHITE, bold=True, alignment=PP_ALIGN.CENTER)
    # Description card below
    card = add_rounded_rect(sl, cx - Inches(0.3), Inches(4.1), Inches(2.0), Inches(1.6))
    ctf = card.text_frame
    ctf.margin_top = Inches(0.15)
    ctf.margin_left = Inches(0.15)
    ctf.word_wrap = True
    set_text(ctf, desc, size=12, color=LIGHT_GRAY, alignment=PP_ALIGN.CENTER)


# ━━━ SLIDE 5: Codebase by the Numbers ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
sl = prs.slides.add_slide(prs.slide_layouts[6])
slide_title(sl, "Codebase at a Glance")

# Top row: 5 stat cards
stats = [
    ("~15,700", "Lines of Code"),
    ("116", "Source Files"),
    ("21", "Database Tables"),
    ("35", "App Screens"),
    ("11", "API Route Modules"),
]
for i, (num, label) in enumerate(stats):
    add_stat_card(sl, Inches(0.6 + i * 2.5), Inches(1.6), num, label)

# Bottom row: 4 stat cards
stats2 = [
    ("9", "Data Models"),
    ("7", "API Clients"),
    ("8", "Git Commits"),
    ("13+", "Operational Scripts"),
]
for i, (num, label) in enumerate(stats2):
    add_stat_card(sl, Inches(0.6 + i * 2.5), Inches(3.2), num, label, accent_color=GREEN)

# LOC breakdown table
add_table_data = [
    ("Backend API (TypeScript)", "2,269", "24"),
    ("Flutter Apps + Shared (Dart)", "10,006", "63"),
    ("Database (SQL)", "545", "5"),
    ("Scripts (JS + Bash)", "2,663", "17"),
    ("Infrastructure (YAML)", "253", "7"),
]

tbl_shape = sl.shapes.add_table(len(add_table_data)+1, 3, Inches(0.6), Inches(4.9), Inches(6.5), Inches(0.32 * (len(add_table_data)+1)))
tbl = tbl_shape.table
tbl.columns[0].width = Inches(3.5)
tbl.columns[1].width = Inches(1.5)
tbl.columns[2].width = Inches(1.5)
headers = ["Component", "Lines of Code", "Files"]
for i, h in enumerate(headers):
    c = tbl.cell(0, i)
    c.text = h
    c.fill.solid()
    c.fill.fore_color.rgb = ACCENT
    for p in c.text_frame.paragraphs:
        p.font.size = Pt(11)
        p.font.color.rgb = WHITE
        p.font.bold = True
        p.font.name = "Calibri"
for r, row in enumerate(add_table_data):
    for c, val in enumerate(row):
        cell = tbl.cell(r+1, c)
        cell.text = val
        cell.fill.solid()
        cell.fill.fore_color.rgb = CARD_BG if r % 2 == 0 else SLIDE_BG
        for p in cell.text_frame.paragraphs:
            p.font.size = Pt(11)
            p.font.color.rgb = WHITE
            p.font.name = "Calibri"


# ━━━ SLIDE 6: What Has Been Built — Backend ━━━━━━━━━━━━━━━━━━━━━━━━━━━━
sl = prs.slides.add_slide(prs.slide_layouts[6])
slide_title(sl, "What Has Been Built", "Backend API + Database")

# Backend API card
card1 = add_rounded_rect(sl, Inches(0.6), Inches(1.6), Inches(6.0), Inches(5.2))
tf = card1.text_frame
tf.margin_top = Inches(0.2)
tf.margin_left = Inches(0.25)
tf.word_wrap = True
set_text(tf, "Backend API  (Node.js / Express / TypeScript)", size=16, color=ACCENT_LIGHT, bold=True)
add_bullet(tf, "11 route modules: auth, users, events, connections, posts, sponsors, vendors, discounts, webhooks, admin, admin-auth", size=12, color=LIGHT_GRAY)
add_bullet(tf, "4 middleware layers: JWT auth, admin auth (token family separation), role-based access, Zod validation", size=12, color=LIGHT_GRAY)
add_bullet(tf, "3 service integrations: Twilio SMS/Verify, AWS SES email, Posh.vip webhooks", size=12, color=LIGHT_GRAY)
add_bullet(tf, "JWT dual-auth: separate 'social' and 'admin' token families prevent cross-app token reuse", size=12, color=LIGHT_GRAY)
add_bullet(tf, "DevCode system: simulator-friendly auth that bypasses Twilio when credentials not configured", size=12, color=LIGHT_GRAY)
add_bullet(tf, "2,269 lines of TypeScript across 24 files", size=12, color=MID_GRAY)

# Database card
card2 = add_rounded_rect(sl, Inches(7.0), Inches(1.6), Inches(5.7), Inches(5.2))
tf2 = card2.text_frame
tf2.margin_top = Inches(0.2)
tf2.margin_left = Inches(0.25)
tf2.word_wrap = True
set_text(tf2, "Database  (PostgreSQL 15 on RDS)", size=16, color=ACCENT_LIGHT, bold=True)
add_bullet(tf2, "21 tables across 3 migrations", size=12, color=LIGHT_GRAY)
add_bullet(tf2, "Core: users, admin_users, events, venues, tickets", size=12, color=LIGHT_GRAY)
add_bullet(tf2, "Social: connections, posts, comments, likes", size=12, color=LIGHT_GRAY)
add_bullet(tf2, "Business: sponsors, vendors, discounts", size=12, color=LIGHT_GRAY)
add_bullet(tf2, "Operations: audit log, analytics tables, GDPR export tracking", size=12, color=LIGHT_GRAY)
add_bullet(tf2, "CASCADE delete design with audit log preservation (SET NULL)", size=12, color=LIGHT_GRAY)
add_bullet(tf2, "Seed data for specialties and dev environment", size=12, color=LIGHT_GRAY)
add_bullet(tf2, "545 lines of SQL across 5 files", size=12, color=MID_GRAY)


# ━━━ SLIDE 7: What Has Been Built — Apps ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
sl = prs.slides.add_slide(prs.slide_layouts[6])
slide_title(sl, "What Has Been Built", "Social App + Admin App + Shared Package")

# Social App
card1 = add_rounded_rect(sl, Inches(0.6), Inches(1.6), Inches(4.0), Inches(5.2))
tf = card1.text_frame
tf.margin_top = Inches(0.2)
tf.margin_left = Inches(0.25)
tf.word_wrap = True
set_text(tf, "Social App  (Flutter/Dart)", size=15, color=ACCENT_LIGHT, bold=True)
add_para(tf, "19 screens, 8 feature modules", size=11, color=MID_GRAY)
add_bullet(tf, "Auth: phone entry + SMS verify", size=12, color=LIGHT_GRAY)
add_bullet(tf, "Onboarding: profile setup", size=12, color=LIGHT_GRAY)
add_bullet(tf, "Events: browse, detail, activation", size=12, color=LIGHT_GRAY)
add_bullet(tf, "Networking: QR display, scanner, connections, digital card", size=12, color=LIGHT_GRAY)
add_bullet(tf, "Community: feed, create post, detail", size=12, color=LIGHT_GRAY)
add_bullet(tf, "Search: user discovery + profiles", size=12, color=LIGHT_GRAY)
add_bullet(tf, "Profile: view, edit, settings", size=12, color=LIGHT_GRAY)
add_bullet(tf, "Perks: sponsor discounts", size=12, color=LIGHT_GRAY)

# Admin App
card2 = add_rounded_rect(sl, Inches(4.9), Inches(1.6), Inches(4.0), Inches(5.2))
tf2 = card2.text_frame
tf2.margin_top = Inches(0.2)
tf2.margin_left = Inches(0.25)
tf2.word_wrap = True
set_text(tf2, "Admin App  (Flutter/Dart)", size=15, color=ACCENT_LIGHT, bold=True)
add_para(tf2, "16 screens, 7 feature modules", size=11, color=MID_GRAY)
add_bullet(tf2, "Auth: email/password login", size=12, color=LIGHT_GRAY)
add_bullet(tf2, "Dashboard: stats overview", size=12, color=LIGHT_GRAY)
add_bullet(tf2, "Users: list, detail, add user", size=12, color=LIGHT_GRAY)
add_bullet(tf2, "Events: list, create, detail", size=12, color=LIGHT_GRAY)
add_bullet(tf2, "Sponsors: management + discounts", size=12, color=LIGHT_GRAY)
add_bullet(tf2, "Vendors: list + form", size=12, color=LIGHT_GRAY)
add_bullet(tf2, "Moderation: posts + announcements", size=12, color=LIGHT_GRAY)

# Shared Package
card3 = add_rounded_rect(sl, Inches(9.2), Inches(1.6), Inches(3.5), Inches(5.2))
tf3 = card3.text_frame
tf3.margin_top = Inches(0.2)
tf3.margin_left = Inches(0.25)
tf3.word_wrap = True
set_text(tf3, "Shared Package", size=15, color=ACCENT_LIGHT, bold=True)
add_para(tf3, "Reused by both apps", size=11, color=MID_GRAY)
add_bullet(tf3, "9 data models with JSON serialization", size=12, color=LIGHT_GRAY)
add_bullet(tf3, "7 API clients (base HTTP + typed endpoints)", size=12, color=LIGHT_GRAY)
add_bullet(tf3, "Secure token storage", size=12, color=LIGHT_GRAY)
add_bullet(tf3, "Phone validators", size=12, color=LIGHT_GRAY)
add_bullet(tf3, "Display formatters", size=12, color=LIGHT_GRAY)
add_bullet(tf3, "Constants / enums", size=12, color=LIGHT_GRAY)


# ━━━ SLIDE 8: Infrastructure & Operations ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
sl = prs.slides.add_slide(prs.slide_layouts[6])
slide_title(sl, "Infrastructure & Operations", "AWS EKS + Kubernetes + operational tooling")

# Infra card
card1 = add_rounded_rect(sl, Inches(0.6), Inches(1.6), Inches(5.8), Inches(3.0))
tf = card1.text_frame
tf.margin_top = Inches(0.2)
tf.margin_left = Inches(0.25)
tf.word_wrap = True
set_text(tf, "Cloud Infrastructure  (AWS)", size=16, color=ACCENT_LIGHT, bold=True)
add_bullet(tf, "EKS cluster (us-east-1) with auto-scaling 2-10 pods", size=12, color=LIGHT_GRAY)
add_bullet(tf, "Kubernetes: deployment, service, ingress, secrets, HPA", size=12, color=LIGHT_GRAY)
add_bullet(tf, "SSL/TLS via ACM on api.industrynight.net", size=12, color=LIGHT_GRAY)
add_bullet(tf, "ECR container registry with Docker build pipeline", size=12, color=LIGHT_GRAY)
add_bullet(tf, "RDS PostgreSQL 15 with port-forward access", size=12, color=LIGHT_GRAY)
add_bullet(tf, "CI/CD: GitHub Actions for API, mobile, and web", size=12, color=LIGHT_GRAY)

# COOP card
card2 = add_rounded_rect(sl, Inches(6.8), Inches(1.6), Inches(5.8), Inches(3.0))
tf2 = card2.text_frame
tf2.margin_top = Inches(0.2)
tf2.margin_left = Inches(0.25)
tf2.word_wrap = True
set_text(tf2, "COOP System  (Cost Optimization)", size=16, color=ACCENT_LIGHT, bold=True)
add_bullet(tf2, "Full teardown: EKS + RDS removed, data preserved in S3", size=12, color=LIGHT_GRAY)
add_bullet(tf2, "Full rebuild: infra recreated from scratch + data restored", size=12, color=LIGHT_GRAY)
add_bullet(tf2, "Database backup/restore via pg_dump (full + per-table)", size=12, color=LIGHT_GRAY)
add_bullet(tf2, "Single entry point: scripts/coop/coop.sh", size=12, color=LIGHT_GRAY)

# Cost cards
add_stat_card(sl, Inches(0.6), Inches(5.0), "~$160/mo", "Full Running", accent_color=AMBER)
add_stat_card(sl, Inches(3.1), Inches(5.0), "~$3/mo", "Hibernated (COOP)", accent_color=GREEN)

# Scripts card
card3 = add_rounded_rect(sl, Inches(5.6), Inches(5.0), Inches(7.0), Inches(1.8))
tf3 = card3.text_frame
tf3.margin_top = Inches(0.15)
tf3.margin_left = Inches(0.25)
tf3.word_wrap = True
set_text(tf3, "Operational Scripts (13+)", size=14, color=ACCENT_LIGHT, bold=True)
add_bullet(tf3, "seed-admin.js, db-reset.js, db-scrub-user.js (GDPR)", size=11, color=LIGHT_GRAY)
add_bullet(tf3, "deploy-api.sh, maintenance.sh, setup-local.sh", size=11, color=LIGHT_GRAY)
add_bullet(tf3, "COOP: status, teardown, rebuild, export, import", size=11, color=LIGHT_GRAY)


# ━━━ SLIDE 9: Architecture Decisions ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
sl = prs.slides.add_slide(prs.slide_layouts[6])
add_table_slide(sl, "Architecture Decisions",
    ["Decision", "Choice", "Rationale"],
    [
        ["Database", "PostgreSQL 15 (RDS)", "Relational model fits domain; direct SQL, no ORM"],
        ["Auth (social)", "Phone + SMS OTP", "Passwordless, phone-based identity for creatives"],
        ["Auth (admin)", "Email + password", "Separate admin_users table, separate token family"],
        ["Mobile framework", "Flutter/Dart", "Single codebase for iOS, Android, Web"],
        ["API framework", "Express + TypeScript", "Proven, team familiarity"],
        ["Orchestration", "AWS EKS (Kubernetes)", "Scalability, infrastructure learning"],
        ["SMS provider", "Twilio (Verify API)", "DevCode fallback for local testing"],
        ["Ticketing", "Posh.vip (webhooks)", "Existing brand presence, staff trained"],
        ["State mgmt", "Provider + ChangeNotifier", "Simple, sufficient for current scope"],
        ["Cost mgmt", "COOP teardown/rebuild", "Reduce AWS spend during downtime"],
    ],
    col_widths=[2.2, 2.8, 3.8]
)


# ━━━ SLIDE 10: Implementation Status ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
sl = prs.slides.add_slide(prs.slide_layouts[6])
slide_title(sl, "Implementation Status vs Plan")

phases = [
    ("1A", "Foundation (Backend + Auth)", "Complete", GREEN),
    ("1B", "Core Mobile App", "Complete", GREEN),
    ("1C", "Verification & QR Networking", "Complete", GREEN),
    ("1D", "Event Social Features", "Screens Built", AMBER),
    ("1E", "Community Board", "Complete", GREEN),
    ("1F", "Creative Search", "Complete", GREEN),
    ("2A", "Admin App - Foundation", "Complete", GREEN),
    ("2B", "Admin App - Event Mgmt", "Complete", GREEN),
    ("2C", "Admin App - Sponsor Mgmt", "Complete", GREEN),
    ("2D", "Admin App - Vendor Mgmt", "Complete", GREEN),
    ("2E", "Admin App - Moderation", "Complete", GREEN),
    ("--", "Admin Auth (email/password)", "In Progress", ACCENT_LIGHT),
    ("3", "Advanced (Stripe, Push, Analytics)", "Not Started", MID_GRAY),
]

# Render as two columns of cards
for i, (phase, desc, status, color) in enumerate(phases):
    col = 0 if i < 7 else 1
    row = i if i < 7 else i - 7
    left = Inches(0.6) if col == 0 else Inches(6.8)
    top = Inches(1.6 + row * 0.73)

    card = add_rounded_rect(sl, left, top, Inches(5.8), Inches(0.6))
    tf = card.text_frame
    tf.margin_top = Inches(0.08)
    tf.margin_left = Inches(0.15)
    tf.word_wrap = True
    p = tf.paragraphs[0]
    p.font.size = Pt(12)
    p.font.name = "Calibri"

    run1 = p.add_run()
    run1.text = f"  {phase}  "
    run1.font.size = Pt(11)
    run1.font.color.rgb = MID_GRAY
    run1.font.bold = True
    run1.font.name = "Calibri"

    run2 = p.add_run()
    run2.text = f"  {desc}"
    run2.font.size = Pt(12)
    run2.font.color.rgb = WHITE
    run2.font.name = "Calibri"

    # Status badge
    badge_w = max(Inches(1.0), Inches(len(status) * 0.1))
    badge = add_rounded_rect(sl, left + Inches(4.3), top + Inches(0.1), Inches(1.3), Inches(0.38), fill_color=color)
    btf = badge.text_frame
    btf.margin_top = Inches(0.0)
    btf.vertical_anchor = MSO_ANCHOR.MIDDLE
    set_text(btf, status, size=9, color=SLIDE_BG, bold=True, alignment=PP_ALIGN.CENTER)


# ━━━ SLIDE 11: Current WIP + What's Next ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
sl = prs.slides.add_slide(prs.slide_layouts[6])
slide_title(sl, "Current Work & What's Next")

# Current WIP
card1 = add_rounded_rect(sl, Inches(0.6), Inches(1.6), Inches(5.8), Inches(4.5))
tf = card1.text_frame
tf.margin_top = Inches(0.2)
tf.margin_left = Inches(0.25)
tf.word_wrap = True
set_text(tf, "In Progress Now", size=18, color=ACCENT_LIGHT, bold=True)
add_para(tf, "Branch: feature/web-admin-login", size=11, color=MID_GRAY)
add_para(tf, "", size=6, color=WHITE)
add_bullet(tf, "Admin auth API routes (login, refresh, me, logout)", size=13, color=LIGHT_GRAY)
add_bullet(tf, "Admin auth middleware (JWT with admin token family)", size=13, color=LIGHT_GRAY)
add_bullet(tf, "admin_users database migration", size=13, color=LIGHT_GRAY)
add_bullet(tf, "Shared Dart AdminUser model + AdminAuthApi client", size=13, color=LIGHT_GRAY)
add_bullet(tf, "seed-admin.js script for bootstrapping accounts", size=13, color=LIGHT_GRAY)
add_bullet(tf, "Restructure: mobile-app -> social-app, web-app -> admin-app", size=13, color=LIGHT_GRAY)

# What's Next
card2 = add_rounded_rect(sl, Inches(6.8), Inches(1.6), Inches(5.8), Inches(4.5))
tf2 = card2.text_frame
tf2.margin_top = Inches(0.2)
tf2.margin_left = Inches(0.25)
tf2.word_wrap = True
set_text(tf2, "Up Next", size=18, color=ACCENT_LIGHT, bold=True)
add_para(tf2, "", size=6, color=WHITE)
items = [
    ("1.", "Complete admin auth", "Finish login flow connecting Admin App to backend"),
    ("2.", "End-to-end testing", "Validate social app auth flow with live backend"),
    ("3.", "First live event test", "Test activation code + QR networking at a real event"),
    ("4.", "API test coverage", "Establish baseline test suite (Jest configured)"),
    ("5.", "Phase 2 planning", "In-app ticketing (Stripe), push notifications, analytics"),
]
for num, title, desc in items:
    add_para(tf2, f"{num}  {title}", size=14, color=WHITE, bold=True, space_before=Pt(10))
    add_para(tf2, f"     {desc}", size=11, color=MID_GRAY, space_before=Pt(0))


# ━━━ SLIDE 12: Technical Debt & Risks ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
sl = prs.slides.add_slide(prs.slide_layouts[6])
add_table_slide(sl, "Known Technical Debt",
    ["Item", "Impact", "Priority"],
    [
        ["No API tests (Jest configured, no tests written)", "Risk of regressions on deploy", "High"],
        ["No DB connectivity check in /health endpoint", "Silent database failures in production", "Medium"],
        ["No pre-deploy migration runner in CI/CD", "Manual migration step required on deploy", "Medium"],
        ["No post-deploy smoke tests", "No automated verification of deploys", "Medium"],
        ["No down-migration files for rollback", "Cannot automatically roll back schema changes", "Low"],
    ],
    col_widths=[4.5, 2.8, 1.5]
)

# Priority legend
tb = add_textbox(sl, Inches(0.6), Inches(4.8), Inches(8), Inches(0.5))
tf = tb.text_frame
tf.word_wrap = True
set_text(tf, "All items are tracked and will be addressed as part of ongoing hardening.", size=12, color=MID_GRAY)


# ━━━ SLIDE 13: Summary ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
sl = prs.slides.add_slide(prs.slide_layouts[6])
set_slide_bg(sl, SLIDE_BG)

bar = sl.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(0), Inches(0), Inches(0.15), Inches(7.5))
bar.fill.solid()
bar.fill.fore_color.rgb = ACCENT
bar.line.fill.background()

tb = add_textbox(sl, Inches(1.0), Inches(1.5), Inches(11), Inches(1.0))
set_text(tb.text_frame, "Summary", size=36, color=WHITE, bold=True)

tb2 = add_textbox(sl, Inches(1.0), Inches(2.5), Inches(10), Inches(4.0))
tf = tb2.text_frame
tf.word_wrap = True
set_text(tf, "In 12 days, we have built:", size=20, color=LIGHT_GRAY)
add_para(tf, "", size=10, color=WHITE)
bullets = [
    "A complete backend API with 11 route modules, dual JWT auth, and 3 external service integrations",
    "A 21-table PostgreSQL database with full schema, migrations, and seed data",
    "A social app with 19 screens covering auth, events, QR networking, community, search, and profiles",
    "An admin app with 16 screens covering user, event, sponsor, vendor, and content management",
    "A shared Dart package with 9 models, 7 API clients, and reusable utilities",
    "Production AWS infrastructure (EKS, RDS, ECR, SSL) with cost-optimization tooling",
    "13+ operational scripts for deployment, database management, and infrastructure lifecycle",
]
for b in bullets:
    add_bullet(tf, b, size=15, color=LIGHT_GRAY)

line = sl.shapes.add_shape(MSO_SHAPE.RECTANGLE, Inches(1.0), Inches(6.3), Inches(4), Pt(2))
line.fill.solid()
line.fill.fore_color.rgb = ACCENT
line.line.fill.background()

tb3 = add_textbox(sl, Inches(1.0), Inches(6.5), Inches(10), Inches(0.5))
set_text(tb3.text_frame, f"~15,700 lines of code  |  116 files  |  {REPORT_DATE}", size=13, color=MID_GRAY)


# ─── Save ───────────────────────────────────────────────────────────────────
output_path = "docs/Industry Night - Executive Brief.pptx"
prs.save(output_path)
print(f"Presentation saved to: {output_path}")
