#!/usr/bin/env python3
"""
Industry Night — UI Design Brief PDF Generator

Two-page dark-themed stakeholder brief.

Usage:
    python3 -m venv /tmp/design-brief-env
    source /tmp/design-brief-env/bin/activate
    pip install reportlab
    python3 scripts/doc-generation/generate-design-brief.py
"""

import os
from datetime import date
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import letter
from reportlab.lib.colors import HexColor, white, black
from reportlab.lib.units import inch
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont

# ── Output ───────────────────────────────────────────────────────────────────
SCRIPT_DIR  = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT   = os.path.dirname(SCRIPT_DIR)
OUTPUT_PATH = os.path.join(REPO_ROOT, 'docs', 'design', 'Industry Night - UI Design Brief.pdf')
os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)

# ── Page setup ───────────────────────────────────────────────────────────────
W, H   = letter          # 612 × 792 pt
MARGIN = 36              # 0.5 inch margins

# ── Brand palette ────────────────────────────────────────────────────────────
C = {
    'bg':         HexColor('#0F0F0F'),
    'surface':    HexColor('#1A1A1A'),
    'card':       HexColor('#242424'),
    'card2':      HexColor('#1E1E1E'),
    'border':     HexColor('#2E2E2E'),
    'purple':     HexColor('#7C3AED'),
    'purple_l':   HexColor('#A855F7'),
    'pink':       HexColor('#FF3D8E'),
    'blue':       HexColor('#1B9CFC'),
    'gold':       HexColor('#F1C40F'),
    'green':      HexColor('#10B981'),
    'red':        HexColor('#EF4444'),
    'amber':      HexColor('#F59E0B'),
    'white':      HexColor('#F5F5F5'),
    'grey1':      HexColor('#A0A0A0'),
    'grey2':      HexColor('#666666'),
    'grey3':      HexColor('#3A3A3A'),
}

# ── Drawing helpers ───────────────────────────────────────────────────────────
def rect(c, x, y, w, h, fill, radius=0, stroke_color=None, stroke_width=0.5):
    c.setFillColor(fill)
    if stroke_color:
        c.setStrokeColor(stroke_color)
        c.setLineWidth(stroke_width)
        c.roundRect(x, y, w, h, radius, fill=1, stroke=1)
    else:
        c.setStrokeColor(fill)
        c.roundRect(x, y, w, h, radius, fill=1, stroke=0)

def line(cv, x1, y1, x2, y2, color, width=0.5):
    cv.setStrokeColor(color)
    cv.setLineWidth(width)
    cv.line(x1, y1, x2, y2)

def text(cv, x, y, string, size=9, color=None, bold=False, align='left'):
    if color is None:
        color = C['white']
    cv.setFillColor(color)
    font = 'Helvetica-Bold' if bold else 'Helvetica'
    cv.setFont(font, size)
    if align == 'right':
        cv.drawRightString(x, y, string)
    elif align == 'center':
        cv.drawCentredString(x, y, string)
    else:
        cv.drawString(x, y, string)

def wrapped_text(cv, x, y, string, size=9, color=None, bold=False,
                 max_width=200, line_height=13):
    """Draw text with word-wrapping. Returns final y position."""
    if color is None:
        color = C['white']
    cv.setFillColor(color)
    font = 'Helvetica-Bold' if bold else 'Helvetica'
    cv.setFont(font, size)

    words = string.split()
    current_line = ''
    current_y = y

    for word in words:
        test_line = (current_line + ' ' + word).strip()
        if cv.stringWidth(test_line, font, size) <= max_width:
            current_line = test_line
        else:
            if current_line:
                cv.drawString(x, current_y, current_line)
                current_y -= line_height
            current_line = word
    if current_line:
        cv.drawString(x, current_y, current_line)
        current_y -= line_height

    return current_y

def label_badge(cv, x, y, text_str, bg_color, text_color=None, font_size=7.5):
    """Small pill-shaped badge."""
    if text_color is None:
        text_color = C['white']
    cv.setFont('Helvetica-Bold', font_size)
    tw = cv.stringWidth(text_str, 'Helvetica-Bold', font_size)
    pad_x, pad_y = 5, 2.5
    bw = tw + pad_x * 2
    bh = font_size + pad_y * 2
    rect(cv, x, y - font_size - pad_y + 1, bw, bh, bg_color, radius=3)
    cv.setFillColor(text_color)
    cv.drawString(x + pad_x, y - font_size + 2, text_str)
    return bw + 4  # return width for chaining

def gradient_bar(cv, x, y, w, h=3):
    """Purple-to-pink gradient bar (simulated with rectangles)."""
    steps = 40
    for i in range(steps):
        t = i / steps
        r = int(0x7C + (0xFF - 0x7C) * t)
        g = int(0x3A + (0x3D - 0x3A) * t)
        b = int(0xED + (0x8E - 0xED) * t)
        cv.setFillColor(HexColor(f'#{r:02x}{g:02x}{b:02x}'))
        cv.rect(x + i * (w / steps), y, w / steps + 1, h, fill=1, stroke=0)

def section_header(cv, x, y, label, width=None):
    """Uppercase section label with accent underline."""
    cv.setFont('Helvetica-Bold', 7)
    cv.setFillColor(C['purple_l'])
    cv.drawString(x, y, label.upper())
    lw = cv.stringWidth(label.upper(), 'Helvetica-Bold', 7)
    line(cv, x, y - 2, x + (lw if width is None else min(width, lw + 20)), y - 2,
         C['purple'], width=0.75)
    return y - 14

def bullet_item(cv, x, y, title, body, col_w, title_color=None, size=8.5):
    """Render a bullet point with bold title and body. Returns new y."""
    if title_color is None:
        title_color = C['white']
    # dot
    cv.setFillColor(C['purple'])
    cv.circle(x + 3, y + 2.5, 1.5, fill=1, stroke=0)

    tx = x + 10
    avail = col_w - 10

    cv.setFont('Helvetica-Bold', size)
    title_w = cv.stringWidth(title + ' ', 'Helvetica-Bold', size)
    cv.setFillColor(title_color)
    cv.drawString(tx, y, title)

    # Body text on same line if it fits, else wrap
    body_x = tx + title_w
    cv.setFont('Helvetica', size)
    body_avail = avail - title_w

    if cv.stringWidth(body, 'Helvetica', size) <= body_avail:
        cv.setFillColor(C['grey1'])
        cv.drawString(body_x, y, body)
        return y - 13
    else:
        # Wrap body onto next lines
        cv.setFillColor(C['grey1'])
        words = body.split()
        cur = ''
        first = True
        cy = y
        for w in words:
            test = (cur + ' ' + w).strip()
            avail_this = body_avail if first else avail
            if cv.stringWidth(test, 'Helvetica', size) <= avail_this:
                cur = test
            else:
                if cur:
                    draw_x = body_x if first else tx
                    cv.drawString(draw_x, cy, cur)
                    cy -= 12
                    first = False
                cur = w
        if cur:
            draw_x = body_x if first else tx
            cv.drawString(draw_x, cy, cur)
            cy -= 12
        return cy - 1


# ── PAGE 1 ────────────────────────────────────────────────────────────────────
def page1(cv):
    # Background
    rect(cv, 0, 0, W, H, C['bg'])

    y = H

    # ── Hero header bar ──────────────────────────────────────────────────────
    header_h = 62
    rect(cv, 0, H - header_h, W, header_h, C['surface'])
    gradient_bar(cv, 0, H - header_h, W, h=2)

    # Logo / wordmark area
    cv.setFillColor(C['purple'])
    cv.setFont('Helvetica-Bold', 7)
    cv.drawString(MARGIN, H - 18, 'INDUSTRY NIGHT')

    # Title
    cv.setFont('Helvetica-Bold', 22)
    cv.setFillColor(C['white'])
    cv.drawString(MARGIN, H - 42, 'UI / UX Design Direction')

    # Date + label — right aligned
    today = date.today().strftime('%B %Y')
    text(cv, W - MARGIN, H - 24, 'DESIGN BRIEF', size=7, color=C['purple_l'],
         bold=True, align='right')
    text(cv, W - MARGIN, H - 36, today, size=9, color=C['grey1'], align='right')
    text(cv, W - MARGIN, H - 48, 'Confidential · For Stakeholder Review',
         size=7.5, color=C['grey2'], align='right')

    y = H - header_h - 14

    # ── Tagline card ─────────────────────────────────────────────────────────
    tq_h = 30
    rect(cv, MARGIN, y - tq_h, W - MARGIN*2, tq_h, C['card'], radius=4,
         stroke_color=C['border'])
    # left accent bar
    rect(cv, MARGIN, y - tq_h, 3, tq_h, C['purple'], radius=0)
    cv.setFont('Helvetica-Oblique', 9)
    cv.setFillColor(C['grey1'])
    tagline = ('"Industry Night looks like DICE.fm decided to build LinkedIn for '
               'creative professionals — and Linear built the back office."')
    cv.drawString(MARGIN + 12, y - 11, tagline[:72])
    cv.drawString(MARGIN + 12, y - 22, tagline[72:])

    y -= tq_h + 12

    # ── Two columns ──────────────────────────────────────────────────────────
    col_gap  = 14
    col_w    = (W - MARGIN*2 - col_gap) / 2
    col_l_x  = MARGIN
    col_r_x  = MARGIN + col_w + col_gap
    col_top  = y

    # ════ LEFT COLUMN ════════════════════════════════════════════════════════

    # — Design Principles —
    y_l = col_top
    y_l = section_header(cv, col_l_x, y_l, 'Design Principles')

    principles = [
        ('Platform recedes.',     'Events and people are the experience. Chrome is minimal.'),
        ('Dark-first.',           '#121212 near-black — warmer and more premium than pure black.'),
        ('Purple brand.',         '#7C3AED → #A855F7 spectrum. Purple-to-pink gradient for key moments.'),
        ('Two fonts only.',       'One expressive display font + Inter. No competing typefaces.'),
        ('4 px grid.',            'All spacing is a multiple of 4 px. Ruthlessly consistent.'),
        ('Semantic color.',       'Red = error. Green = success. Never decorative.'),
        ('Skeleton loading.',     'Content-shaped placeholders everywhere. No spinners.'),
        ('Side drawers for CRUD.','Admin never navigates away from a list to create or edit.'),
    ]
    for title, body in principles:
        y_l = bullet_item(cv, col_l_x, y_l, title, body, col_w)

    y_l -= 8

    # — Color Palette —
    y_l = section_header(cv, col_l_x, y_l, 'Color Palette')

    swatches = [
        ('#0F0F0F', 'BG'),
        ('#1A1A1A', 'Surface'),
        ('#242424', 'Elevated'),
        ('#2E2E2E', 'Border'),
        ('#7C3AED', 'Purple'),
        ('#A855F7', 'Accent'),
        ('#FF3D8E', 'Energy'),
        ('#1B9CFC', 'Blue'),
        ('#F1C40F', 'Gold'),
        ('#10B981', 'Success'),
    ]
    sw_size  = 22
    sw_gap   = 4
    sw_per_row = 5
    for i, (hex_c, label) in enumerate(swatches):
        row = i // sw_per_row
        col = i % sw_per_row
        sx = col_l_x + col * (sw_size + sw_gap)
        sy = y_l - row * (sw_size + 14) - sw_size

        rect(cv, sx, sy, sw_size, sw_size, HexColor(hex_c), radius=3,
             stroke_color=C['border'], stroke_width=0.5)
        cv.setFont('Helvetica', 6.5)
        cv.setFillColor(C['grey2'])
        lw = cv.stringWidth(label, 'Helvetica', 6.5)
        cv.drawString(sx + (sw_size - lw) / 2, sy - 9, label)

    y_l -= (len(swatches) / sw_per_row) * (sw_size + 14) + 4

    y_l -= 8

    # — Typography —
    y_l = section_header(cv, col_l_x, y_l, 'Typography Scale')

    type_rows = [
        ('Display',  'Clash Display / Satoshi',  '40–48 px  ·  Bold'),
        ('H1 – H2',  'Inter Display',             '28–34 px  ·  Semibold'),
        ('Body',     'Inter',                     '14–16 px  ·  Regular'),
        ('Label',    'Inter',                     '12–13 px  ·  Medium'),
        ('Mono',     'JetBrains Mono',            '13 px  ·  Regular'),
    ]
    for role, font, spec in type_rows:
        cv.setFont('Helvetica-Bold', 8.5)
        cv.setFillColor(C['white'])
        cv.drawString(col_l_x, y_l, role)
        cv.setFont('Helvetica', 8.5)
        cv.setFillColor(C['grey1'])
        cv.drawString(col_l_x + 52, y_l, font)
        cv.setFont('Helvetica', 7.5)
        cv.setFillColor(C['grey2'])
        cv.drawString(col_l_x + 52, y_l - 10, spec)
        y_l -= 23

    # ════ RIGHT COLUMN ═══════════════════════════════════════════════════════

    y_r = col_top

    # — Why This Matters —
    y_r = section_header(cv, col_r_x, y_r, 'Why This Matters')
    why = ('IN is migrating its Admin App and building a new Social Web experience '
           'in React. This brief synthesises ~30 platform analyses across event/nightlife '
           'apps, admin dashboards, and creative industry networks to establish a shared '
           'visual language before a line of React is written.')
    y_r = wrapped_text(cv, col_r_x, y_r, why, size=8.5, color=C['grey1'],
                       max_width=col_w, line_height=13)
    y_r -= 10

    # — The Design Opportunity —
    y_r = section_header(cv, col_r_x, y_r, 'The Design Opportunity')

    cv.setFont('Helvetica', 8.5)
    cv.setFillColor(C['grey1'])
    cv.drawString(col_r_x, y_r, 'No competitor combines all of the following:')
    y_r -= 13

    opportunity = [
        ('Dark creative aesthetic', '(DICE.fm) + real-time QR networking'),
        ('Community feed', '(Behance-style) + business integration (sponsor perks)'),
        ('Multihyphenate identity', '(Polywork) + full event lifecycle'),
        ('Linear-quality admin CRM', 'that directly powers the social experience'),
    ]
    for bold_part, rest in opportunity:
        cv.setFillColor(C['purple'])
        cv.rect(col_r_x + 2, y_r + 2, 3, 3, fill=1, stroke=0)
        cv.setFont('Helvetica-Bold', 8.5)
        cv.setFillColor(C['white'])
        bw = cv.stringWidth(bold_part + ' ', 'Helvetica-Bold', 8.5)
        cv.drawString(col_r_x + 10, y_r, bold_part)
        cv.setFont('Helvetica', 8.5)
        cv.setFillColor(C['grey1'])
        # wrap rest
        rest_full = rest
        avail = col_w - 10 - bw
        if cv.stringWidth(rest_full, 'Helvetica', 8.5) <= avail:
            cv.drawString(col_r_x + 10 + bw, y_r, rest_full)
            y_r -= 13
        else:
            words = rest_full.split()
            first_line = ''
            for word in words:
                test = (first_line + ' ' + word).strip()
                if cv.stringWidth(test, 'Helvetica', 8.5) <= avail:
                    first_line = test
                else:
                    break
            cv.drawString(col_r_x + 10 + bw, y_r, first_line)
            y_r -= 12
            remainder = rest_full[len(first_line):].strip()
            if remainder:
                cv.drawString(col_r_x + 10, y_r, remainder)
                y_r -= 13

    y_r -= 8

    # — Social Web Exemplars —
    y_r = section_header(cv, col_r_x, y_r, 'Social Web — Top References')

    social_refs = [
        ('DICE.fm',          C['purple_l'], 'Event discovery — dark mode, imagery-first cards, social graph'),
        ('Partiful',         C['pink'],     'Event detail — social proof, RSVP visibility, pre-event energy'),
        ('Resident Advisor', C['purple_l'], 'Community depth — editorial + events + social layers'),
        ('Shotgun',          C['blue'],     'Color palette — purple-on-dark that reads creative/premium'),
        ('Read.cv',          C['purple_l'], 'Profiles — minimal, work gallery first, specialty badges'),
        ('Luma',             C['blue'],     'Gradient heroes, backdrop-blur nav, confident asymmetric layout'),
    ]
    for platform, badge_c, desc in social_refs:
        cv.setFont('Helvetica-Bold', 8.5)
        cv.setFillColor(badge_c)
        pw = cv.stringWidth(platform, 'Helvetica-Bold', 8.5)
        cv.drawString(col_r_x, y_r, platform)
        cv.setFont('Helvetica', 8)
        cv.setFillColor(C['grey1'])
        # Try same line
        desc_x = col_r_x + pw + 5
        avail = col_w - pw - 5
        if cv.stringWidth(' — ' + desc, 'Helvetica', 8) <= avail:
            cv.setFillColor(C['grey2'])
            cv.drawString(desc_x, y_r, '— ')
            cv.setFillColor(C['grey1'])
            cv.drawString(desc_x + cv.stringWidth('— ', 'Helvetica', 8), y_r, desc)
            y_r -= 13
        else:
            y_r -= 12
            y_r = wrapped_text(cv, col_r_x + 6, y_r, desc, size=8,
                               color=C['grey1'], max_width=col_w - 6, line_height=11)

    y_r -= 8

    # — Admin Exemplars —
    y_r = section_header(cv, col_r_x, y_r, 'Admin — Top References')

    admin_refs = [
        ('Linear',          C['purple_l'], 'Gold standard — calm design, sidebar hierarchy, Cmd+K'),
        ('Stripe',          C['blue'],     'Data excellence — progressive disclosure, semantic color'),
        ('Shopify Polaris', C['purple_l'], 'Design system — token structure, spacing, 60+ components'),
        ('Clerk',           C['blue'],     'User management — loading/empty/error states for every screen'),
        ('Vercel',          C['purple_l'], 'Sidebar navigation, project cards, unified status indicators'),
    ]
    for platform, badge_c, desc in admin_refs:
        cv.setFont('Helvetica-Bold', 8.5)
        cv.setFillColor(badge_c)
        pw = cv.stringWidth(platform, 'Helvetica-Bold', 8.5)
        cv.drawString(col_r_x, y_r, platform)
        cv.setFont('Helvetica', 8)
        cv.setFillColor(C['grey1'])
        desc_x = col_r_x + pw + 5
        avail = col_w - pw - 5
        if cv.stringWidth(' — ' + desc, 'Helvetica', 8) <= avail:
            cv.setFillColor(C['grey2'])
            cv.drawString(desc_x, y_r, '— ')
            cv.setFillColor(C['grey1'])
            cv.drawString(desc_x + cv.stringWidth('— ', 'Helvetica', 8), y_r, desc)
            y_r -= 13
        else:
            y_r -= 12
            y_r = wrapped_text(cv, col_r_x + 6, y_r, desc, size=8,
                               color=C['grey1'], max_width=col_w - 6, line_height=11)

    # ── Column divider ────────────────────────────────────────────────────────
    line(cv, col_r_x - col_gap/2, col_top + 4, col_r_x - col_gap/2,
         min(y_l, y_r) - 10, C['border'])

    # ── Footer ────────────────────────────────────────────────────────────────
    footer_y = 22
    line(cv, MARGIN, footer_y + 10, W - MARGIN, footer_y + 10, C['border'])
    text(cv, MARGIN, footer_y, 'Industry Night  ·  Confidential', size=7,
         color=C['grey2'])
    text(cv, W/2, footer_y, 'Full research: docs/design/ux_design_direction.md',
         size=7, color=C['grey2'], align='center')
    text(cv, W - MARGIN, footer_y, f'Page 1 of 2  ·  {date.today().strftime("%B %d, %Y")}',
         size=7, color=C['grey2'], align='right')


# ── PAGE 2 ────────────────────────────────────────────────────────────────────
def page2(cv):
    rect(cv, 0, 0, W, H, C['bg'])

    # ── Header ───────────────────────────────────────────────────────────────
    header_h = 52
    rect(cv, 0, H - header_h, W, header_h, C['surface'])
    gradient_bar(cv, 0, H - header_h, W, h=2)

    cv.setFillColor(C['purple'])
    cv.setFont('Helvetica-Bold', 7)
    cv.drawString(MARGIN, H - 16, 'INDUSTRY NIGHT')

    cv.setFont('Helvetica-Bold', 18)
    cv.setFillColor(C['white'])
    cv.drawString(MARGIN, H - 38, 'Design Exemplars by Surface')

    text(cv, W - MARGIN, H - 22, 'Reference mapping — what to study for each screen',
         size=8, color=C['grey1'], align='right')
    text(cv, W - MARGIN, H - 36, 'Admin App  +  Social Web',
         size=9, color=C['grey2'], align='right')

    y = H - header_h - 16

    # ── Table helper ──────────────────────────────────────────────────────────
    def draw_table(title, rows, y_start, accent_color):
        """Draw a section table. Returns final y."""
        y = y_start
        y = section_header(cv, MARGIN, y, title)
        y -= 2

        col_widths = [148, 140, W - MARGIN*2 - 148 - 140]
        headers = ['Surface', 'Primary Reference', 'Key Pattern']

        row_h   = 18
        total_w = W - MARGIN*2

        # Header row
        rect(cv, MARGIN, y - row_h, total_w, row_h, C['card'], radius=0)
        line(cv, MARGIN, y - row_h, MARGIN + total_w, y - row_h, accent_color, width=0.75)

        x_offset = MARGIN + 8
        for i, (hdr, cw) in enumerate(zip(headers, col_widths)):
            cv.setFont('Helvetica-Bold', 7.5)
            cv.setFillColor(accent_color)
            cv.drawString(x_offset, y - 12, hdr.upper())
            x_offset += cw

        y -= row_h

        for idx, (surface, ref, pattern) in enumerate(rows):
            bg = C['card2'] if idx % 2 == 0 else C['bg']

            # Estimate row height (pattern may wrap)
            cv.setFont('Helvetica', 8)
            pat_w = col_widths[2] - 16
            words = pattern.split()
            lines_needed = 1
            cur = ''
            for word in words:
                test = (cur + ' ' + word).strip()
                if cv.stringWidth(test, 'Helvetica', 8) > pat_w:
                    lines_needed += 1
                    cur = word
                else:
                    cur = test
            this_row_h = max(row_h, 12 * lines_needed + 8)

            rect(cv, MARGIN, y - this_row_h, total_w, this_row_h, bg)
            # subtle bottom border
            line(cv, MARGIN, y - this_row_h, MARGIN + total_w,
                 y - this_row_h, C['border'], width=0.3)

            xo = MARGIN + 8
            base_y = y - this_row_h/2 - 4

            # Surface
            cv.setFont('Helvetica-Bold', 8.5)
            cv.setFillColor(C['white'])
            cv.drawString(xo, base_y, surface)
            xo += col_widths[0]

            # Reference (colored)
            cv.setFont('Helvetica-Bold', 8.5)
            cv.setFillColor(accent_color)
            cv.drawString(xo, base_y, ref)
            xo += col_widths[1]

            # Pattern (wrapped)
            cv.setFont('Helvetica', 8)
            cv.setFillColor(C['grey1'])
            words2 = pattern.split()
            cur2 = ''
            py = y - 9
            first_line = True
            for word in words2:
                test2 = (cur2 + ' ' + word).strip()
                if cv.stringWidth(test2, 'Helvetica', 8) <= pat_w:
                    cur2 = test2
                else:
                    cv.drawString(xo, py, cur2)
                    py -= 11
                    cur2 = word
                    first_line = False
            if cur2:
                cv.drawString(xo, py, cur2)

            y -= this_row_h

        return y

    # ── Social Web table ──────────────────────────────────────────────────────
    social_rows = [
        ('Event Discovery',   'DICE.fm + Resident Advisor',  'Dark mode event cards, imagery-first, friend presence visible on cards'),
        ('Event Detail',      'Partiful + Luma',             'Social proof (who\'s attending), gradient hero, pre-event comments'),
        ('User Profile',      'Read.cv + The Dots',          'Minimal gallery-first layout, specialty badges as primary identity'),
        ('Community Feed',    'Behance + Dribbble',          'Gallery grid, creative work showcase, collaboration credits'),
        ('QR Networking',     'Blinq / Popl',                'One-action scan, instant visual confirmation, celebration overlay'),
        ('Perks / Sponsors',  'Fever + Shotgun',             'Sponsor discovery cards, brand presentation, redemption flow'),
    ]

    y = draw_table('Social Web App', social_rows, y, C['purple_l'])
    y -= 16

    # ── Admin table ───────────────────────────────────────────────────────────
    admin_rows = [
        ('Dashboard',           'Linear + Stripe',       'Calm sidebar, stat cards, semantic data density, Cmd+K palette'),
        ('Event Management',    'Shopify Admin + Notion', 'CRUD side drawers, image gallery management, publish status gate'),
        ('Customer / CRM',      'Stripe + HubSpot',      'Progressive disclosure, tabbed detail view, relationship tracking'),
        ('User Management',     'Clerk + Linear',         'User table, status badges, verification workflow, ban actions'),
        ('Analytics',           'Stripe + Vercel',       'Trend cards, semantic chart colors, period selectors'),
        ('Products / Catalog',  'Shopify Polaris',        'Product list, status pills, pricing display, inline editing'),
    ]

    y = draw_table('Admin App', admin_rows, y, C['blue'])
    y -= 18

    # ── Implementation roadmap ────────────────────────────────────────────────
    line(cv, MARGIN, y + 2, W - MARGIN, y + 2, C['border'])
    y -= 4
    y = section_header(cv, MARGIN, y, 'Implementation Sequence')

    phases = [
        ('Phase 0',  'Design Tokens',       '#121212 BG, purple accent, 4 px spacing grid, display font selection (Clash Display / Satoshi)'),
        ('Phase 1',  'Component Library',   'Button, Badge, Card, Avatar, Table, Side Drawer, Toast, Skeleton — reference Shopify Polaris token structure'),
        ('Phase 2',  'Admin Shell',         'Sidebar + top bar layout, event list + detail, customer CRM detail, user management screens'),
        ('Phase 3',  'Social Hero Screens', 'Event discovery grid, event detail with social proof, user profile with gallery, community feed'),
        ('Phase 4',  'Social Interactions', 'QR celebration overlay, connection cards, perks discovery, redemption tracking flow'),
    ]

    phase_colors = [C['purple'], C['purple_l'], C['blue'], C['pink'], C['gold']]
    total_w = W - MARGIN*2
    for i, (phase, title, desc) in enumerate(phases):
        bg = C['card2'] if i % 2 == 0 else C['bg']
        row_h = 16
        rect(cv, MARGIN, y - row_h, total_w, row_h, bg)

        pc = phase_colors[i % len(phase_colors)]
        # Phase pill
        cv.setFont('Helvetica-Bold', 7)
        cv.setFillColor(pc)
        cv.drawString(MARGIN + 6, y - 11, phase)

        cv.setFont('Helvetica-Bold', 8)
        cv.setFillColor(C['white'])
        cv.drawString(MARGIN + 58, y - 11, title)

        cv.setFont('Helvetica', 8)
        cv.setFillColor(C['grey1'])
        cv.drawString(MARGIN + 175, y - 11, desc[:90])
        if len(desc) > 90:
            y -= row_h
            rect(cv, MARGIN, y - row_h, total_w, row_h, bg)
            cv.setFont('Helvetica', 8)
            cv.setFillColor(C['grey1'])
            cv.drawString(MARGIN + 175, y - 11, desc[90:])

        y -= row_h

    # ── Avoid panel ───────────────────────────────────────────────────────────
    y -= 12
    avoid_x = MARGIN
    avoid_w = (total_w - 8) / 3

    avoids = [
        ('Posh.vip', 'Three conflicting fonts, no social layer, overdesigned workflows'),
        ('Eventbrite', 'Corporate blandness — great IA, zero personality for creative audiences'),
        ('Pure Black / Light-only', '#000 is harsh; #121212 is premium. Dark-first always.'),
    ]

    for i, (title, note) in enumerate(avoids):
        ax = avoid_x + i * (avoid_w + 4)
        rect(cv, ax, y - 36, avoid_w, 36, C['card'], radius=4,
             stroke_color=C['red'], stroke_width=0.4)
        cv.setFont('Helvetica-Bold', 7.5)
        cv.setFillColor(C['red'])
        cv.drawString(ax + 8, y - 12, f'✗  {title}')
        cv.setFont('Helvetica', 7.5)
        cv.setFillColor(C['grey1'])
        # wrap note
        nw = avoid_w - 16
        words = note.split()
        lines = ['']
        for word in words:
            test = (lines[-1] + ' ' + word).strip()
            if cv.stringWidth(test, 'Helvetica', 7.5) <= nw:
                lines[-1] = test
            else:
                lines.append(word)
        ny = y - 22
        for ln in lines[:2]:
            cv.drawString(ax + 8, ny, ln)
            ny -= 10

    # ── Footer ────────────────────────────────────────────────────────────────
    footer_y = 22
    line(cv, MARGIN, footer_y + 10, W - MARGIN, footer_y + 10, C['border'])
    text(cv, MARGIN, footer_y, 'Industry Night  ·  Confidential', size=7, color=C['grey2'])
    text(cv, W/2, footer_y, 'Full research: docs/design/ux_design_direction.md',
         size=7, color=C['grey2'], align='center')
    text(cv, W - MARGIN, footer_y, f'Page 2 of 2  ·  {date.today().strftime("%B %d, %Y")}',
         size=7, color=C['grey2'], align='right')


# ── Build ─────────────────────────────────────────────────────────────────────
def build():
    c = canvas.Canvas(OUTPUT_PATH, pagesize=letter)
    c.setTitle('Industry Night — UI Design Brief')
    c.setAuthor('Industry Night')
    c.setSubject('UI/UX Design Direction')

    page1(c)
    c.showPage()
    page2(c)
    c.save()
    print(f'✓  PDF generated: {OUTPUT_PATH}')


if __name__ == '__main__':
    build()
