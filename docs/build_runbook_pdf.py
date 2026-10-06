#!/usr/bin/env python3
"""Build docs/DevOps-Project-Runbook.pdf from docs/RUNBOOK.md.

    pip install reportlab
    python3 docs/build_runbook_pdf.py

Handles the Markdown subset used by the runbook: headings (#, ##, ###), paragraphs,
bullet and numbered lists, fenced code blocks, pipe tables, > callouts, `code`, **bold**.
"""
import re
from datetime import date
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (CondPageBreak, PageBreak, Paragraph, Preformatted, Spacer, Table,
                                TableStyle)
from reportlab.platypus.doctemplate import BaseDocTemplate, NextPageTemplate, PageTemplate
from reportlab.platypus.frames import Frame
from reportlab.platypus.tableofcontents import TableOfContents

HERE = Path(__file__).resolve().parent
SRC = HERE / "RUNBOOK.md"
OUT = HERE / "DevOps-Project-Runbook.pdf"

NAVY = colors.HexColor("#1F3A5F")
ACCENT = colors.HexColor("#E8833A")
CODE_BG = colors.HexColor("#F4F6F8")
CODE_BORDER = colors.HexColor("#D5DBE1")
NOTE_BG = colors.HexColor("#FFF6E5")
GRID = colors.HexColor("#C9D1DA")
HEAD_BG = colors.HexColor("#E6ECF3")

ss = getSampleStyleSheet()
BODY = ParagraphStyle("body", parent=ss["BodyText"], fontName="Helvetica", fontSize=9.5, leading=13.5, spaceAfter=5)
H1 = ParagraphStyle("h1", parent=BODY, fontName="Helvetica-Bold", fontSize=17, leading=21, textColor=NAVY,
                    spaceBefore=4, spaceAfter=8)
H3 = ParagraphStyle("h3", parent=BODY, fontName="Helvetica-Bold", fontSize=10.5, leading=14, textColor=ACCENT,
                    spaceBefore=6, spaceAfter=3)
CELL = ParagraphStyle("cell", parent=BODY, fontSize=8.3, leading=11, spaceAfter=0)
CELL_HEAD = ParagraphStyle("cellh", parent=CELL, fontName="Helvetica-Bold", textColor=NAVY)
CODE = ParagraphStyle("code", fontName="Courier", fontSize=7.2, leading=9.2, textColor=colors.HexColor("#1B1F23"))
LIST = ParagraphStyle("list", parent=BODY, leftIndent=14, bulletIndent=3, spaceAfter=2.5)
NOTE = ParagraphStyle("note", parent=BODY, fontSize=9, leading=12.5, spaceAfter=0)


def inline(text):
    """Escape XML and convert `code`, **bold** and links to reportlab markup."""
    parts = re.split(r"(`[^`]+`)", text)
    out = []
    for part in parts:
        if part.startswith("`") and part.endswith("`") and len(part) > 1:
            code = part[1:-1].replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
            out.append(f'<font face="Courier" size="8.6" color="#B4372F">{code}</font>')
        else:
            p = part.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
            p = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r"\1", p)
            p = re.sub(r"\*\*([^*]+)\*\*", r"<b>\1</b>", p)
            p = re.sub(r"(?<![\w*])\*([^*\s][^*]*)\*(?![\w*])", r"<i>\1</i>", p)
            p = re.sub(r"(https?://[^\s<,)]+)", r'<link href="\1" color="#1F5FA8">\1</link>', p)
            out.append(p)
    return "".join(out)


def code_block(lines, width):
    pre = Preformatted("\n".join(lines), CODE, maxLineLength=112, newLineChars="  ")
    t = Table([[pre]], colWidths=[width])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), CODE_BG),
        ("BOX", (0, 0), (-1, -1), 0.6, CODE_BORDER),
        ("LINEBEFORE", (0, 0), (0, -1), 2.5, NAVY),
        ("LEFTPADDING", (0, 0), (-1, -1), 7), ("RIGHTPADDING", (0, 0), (-1, -1), 5),
        ("TOPPADDING", (0, 0), (-1, -1), 5), ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
    ]))
    return [t, Spacer(1, 6)]


def md_table(rows, width):
    cells = [[c.strip() for c in r.strip().strip("|").split("|")] for r in rows]
    header, body = cells[0], [r for r in cells[2:]]
    ncol = len(header)
    # Column widths proportional to content length, clamped so no column gets crushed
    lens = [max(len(re.sub(r"[`*]", "", r[i])) if i < len(r) else 0 for r in cells[:1] + body) for i in range(ncol)]
    lens = [min(max(l, 6), 60) for l in lens]
    widths = [width * l / sum(lens) for l in lens]
    data = [[Paragraph(inline(h), CELL_HEAD) for h in header]]
    for r in body:
        r = (r + [""] * ncol)[:ncol]
        data.append([Paragraph(inline(c), CELL) for c in r])
    t = Table(data, colWidths=widths, repeatRows=1)
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), HEAD_BG),
        ("GRID", (0, 0), (-1, -1), 0.4, GRID),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#FAFBFC")]),
        ("LEFTPADDING", (0, 0), (-1, -1), 4), ("RIGHTPADDING", (0, 0), (-1, -1), 4),
        ("TOPPADDING", (0, 0), (-1, -1), 3), ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
    ]))
    return [t, Spacer(1, 8)]


def callout(text, width):
    t = Table([[Paragraph(inline(text), NOTE)]], colWidths=[width])
    t.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), NOTE_BG),
        ("LINEBEFORE", (0, 0), (0, -1), 3, ACCENT),
        ("LEFTPADDING", (0, 0), (-1, -1), 8), ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ("TOPPADDING", (0, 0), (-1, -1), 5), ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
    ]))
    return [t, Spacer(1, 7)]


class RunbookDoc(BaseDocTemplate):
    def __init__(self, filename, **kw):
        super().__init__(filename, pagesize=A4, leftMargin=18 * mm, rightMargin=18 * mm,
                         topMargin=20 * mm, bottomMargin=18 * mm, **kw)
        frame = Frame(self.leftMargin, self.bottomMargin, self.width, self.height, id="f")
        self.addPageTemplates([
            PageTemplate("cover", [frame], onPage=self._cover),
            PageTemplate("body", [frame], onPage=self._decorate),
        ])

    def afterFlowable(self, flowable):
        # Feed headings into the table of contents
        if isinstance(flowable, Paragraph) and flowable.style.name in ("h2", "h3"):
            level = 0 if flowable.style.name == "h2" else 1
            text = flowable.getPlainText()
            key = f"h{id(flowable)}"
            self.canv.bookmarkPage(key)
            self.canv.addOutlineEntry(text, key, level=level, closed=level > 0)
            self.notify("TOCEntry", (level, text, self.page, key))

    def _cover(self, canv, doc):
        canv.saveState()
        canv.setFillColor(NAVY)
        canv.rect(0, A4[1] - 95 * mm, A4[0], 95 * mm, stroke=0, fill=1)
        canv.setFillColor(ACCENT)
        canv.rect(0, A4[1] - 98 * mm, A4[0], 3 * mm, stroke=0, fill=1)
        canv.restoreState()

    def _decorate(self, canv, doc):
        canv.saveState()
        canv.setStrokeColor(GRID)
        canv.setLineWidth(0.5)
        canv.line(doc.leftMargin, A4[1] - 13 * mm, A4[0] - doc.rightMargin, A4[1] - 13 * mm)
        canv.setFont("Helvetica", 7.5)
        canv.setFillColor(colors.HexColor("#6A737D"))
        canv.drawString(doc.leftMargin, A4[1] - 11 * mm, "End-to-End DevOps Project on AWS - Runbook")
        canv.drawRightString(A4[0] - doc.rightMargin, A4[1] - 11 * mm, "github.com/gh-vishwesh/End-to-End-DevOps-Project")
        canv.drawCentredString(A4[0] / 2, 10 * mm, f"Page {doc.page}")
        canv.restoreState()


def build():
    lines = SRC.read_text(encoding="utf-8").splitlines()
    doc = RunbookDoc(str(OUT), title="End-to-End DevOps Project on AWS - Runbook",
                     author="Vishwesh Pandey", subject="Terraform, EKS, Jenkins, ArgoCD, Trivy, Prometheus, Grafana")
    W = doc.width
    story = []

    # ---- Cover ----
    title = lines[0].lstrip("# ").strip()
    subtitle = lines[2].strip()
    cover_title = ParagraphStyle("ct", fontName="Helvetica-Bold", fontSize=24, leading=30, textColor=colors.white)
    cover_sub = ParagraphStyle("cs", fontName="Helvetica", fontSize=11, leading=15, textColor=colors.HexColor("#DCE6F2"))
    story += [Spacer(1, 18 * mm), Paragraph(title, cover_title), Spacer(1, 6), Paragraph(subtitle, cover_sub),
              Spacer(1, 48 * mm)]
    meta = ParagraphStyle("meta", parent=BODY, fontSize=10, leading=15)
    i = 3
    intro = []
    while i < len(lines) and not lines[i].startswith("## "):
        if lines[i].strip():
            intro.append(lines[i].strip())
        i += 1
    for para in intro:
        story.append(Paragraph(inline(para), meta))
    story += [Spacer(1, 10),
              Paragraph(f"Version: {date.today():%d %B %Y} &nbsp;&nbsp;|&nbsp;&nbsp; Author: Vishwesh Pandey", meta)]

    # ---- Table of contents ----
    story += [NextPageTemplate("body"), PageBreak(), Paragraph("Contents", H1)]
    toc = TableOfContents()
    toc.levelStyles = [
        ParagraphStyle("toc0", fontName="Helvetica-Bold", fontSize=10, leading=14, leftIndent=0, textColor=NAVY),
        ParagraphStyle("toc1", fontName="Helvetica", fontSize=8.8, leading=11.5, leftIndent=14),
    ]
    story += [toc, PageBreak()]

    # ---- Body ----
    para = []
    first_h2 = True

    def flush():
        if para:
            story.append(Paragraph(inline(" ".join(para)), BODY))
            para.clear()

    while i < len(lines):
        line = lines[i]
        s = line.strip()
        if s.startswith("```"):
            flush()
            j = i + 1
            block = []
            while j < len(lines) and not lines[j].strip().startswith("```"):
                block.append(lines[j])
                j += 1
            story += code_block(block, W)
            i = j + 1
            continue
        if s.startswith("|"):
            flush()
            rows = []
            while i < len(lines) and lines[i].strip().startswith("|"):
                rows.append(lines[i])
                i += 1
            story += md_table(rows, W)
            continue
        if s.startswith("## "):
            flush()
            if not first_h2:
                story.append(CondPageBreak(110 * mm))  # new page only if little room is left
            first_h2 = False
            story.append(Paragraph(inline(s[3:]), ParagraphStyle("h2", parent=H1)))
        elif s.startswith("### "):
            flush()
            # keepWithNext keeps a sub-heading on the same page as what follows it
            story.append(Paragraph(inline(s[4:]), ParagraphStyle("h3", parent=H3, keepWithNext=1)))
        elif s.startswith("> "):
            flush()
            text = [s[2:]]
            while i + 1 < len(lines) and lines[i + 1].strip().startswith(">"):
                i += 1
                text.append(lines[i].strip().lstrip("> "))
            story += callout(" ".join(text), W)
        elif re.match(r"^[-*] ", s):
            flush()
            story.append(Paragraph(inline(s[2:]), LIST, bulletText="•"))
        elif re.match(r"^\d+\. ", s):
            flush()
            n, rest = s.split(". ", 1)
            story.append(Paragraph(inline(rest), LIST, bulletText=f"{n}."))
        elif not s:
            flush()
        else:
            para.append(s)
        i += 1
    flush()

    doc.multiBuild(story)
    print(f"wrote {OUT.relative_to(HERE.parent)}")


if __name__ == "__main__":
    build()
