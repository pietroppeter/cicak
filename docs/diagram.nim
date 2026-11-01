## Static SVG of the REPL service architecture (same layout as the Claude Doc diagram).
import std/strformat

# colours come from the dev-log theme, so the diagram follows light and dark mode
const
  edge = "var(--mute)"
  ink = "var(--ink)"
  quiet = "var(--mute)"
  accent = "var(--moss)"
  tint = "var(--out-bg)"
  left = 36
  wide = 688

proc box(x, y, w, h: int; fill = "none"; stroke = edge; sw = 1.25; fillOpacity = 1.0): string =
  &"""<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="8" style="fill: {fill}; fill-opacity: {fillOpacity}; stroke: {stroke}; stroke-width: {sw}"/>"""

proc label(x, y: int; s: string; size = 13.0; bold = false; color = ink): string =
  let weight = if bold: "600" else: "400"
  &"""<text x="{x}" y="{y}" text-anchor="middle" font-size="{size}" font-weight="{weight}" style="fill: {color}">{s}</text>"""

proc arrow(x, y1, y2: int): string =
  &"""<path d="M{x} {y1}V{y2}" style="stroke: {edge}; stroke-width: 1.25; fill: none" marker-end="url(#arch-arrow)"/>"""

proc architectureSvg*(): string =
  const frontEnds = [
    ("Terminal REPL", "in your shell"),
    ("Jupyter kernel", "translates Jupyter messages"),
    ("Editor plugin", "send code to the REPL"),
    ("Python client", "nimlang, notebook magics")]
  const backends = ["Re-run backend (v0)", "HCR cells as modules", "nlvm JIT (maybe)"]
  result = """<svg viewBox="0 0 760 480" role="img" aria-label="Front ends stay thin: one server drives the engine and the worker" font-family="Familjen Grotesk, system-ui, sans-serif" style="max-width: 100%; height: auto">"""
  result.add &"""<defs><marker id="arch-arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M0 0L10 5L0 10z" style="fill: {edge}"/></marker></defs>"""
  result.add &"""<text x="{left}" y="32" font-size="15" font-weight="600" style="fill: {ink}">Front ends stay thin: one server drives the engine and the worker</text>"""
  for i, (name, sub) in frontEnds:
    let x = left + i * 176
    result.add box(x, 56, 160, 56)
    result.add label(x + 80, 80, name, bold = true)
    result.add label(x + 80, 97, sub, 11.5, color = quiet)
    result.add arrow(x + 80, 112, 158)
  result.add box(left, 160, wide, 72, fill = accent, stroke = accent, sw = 2, fillOpacity = 0.12)
  result.add label(380, 184, "nimrepld server", bold = true)
  result.add label(380, 202, "JSON-RPC 2.0 over stdio by default, or a Unix / TCP socket", 11.5)
  result.add label(380, 218, "a socket lets several front ends share one session", 11.5, color = quiet)
  result.add arrow(380, 232, 262)
  result.add box(left, 264, wide, 104)
  result.add label(380, 288, "Engine library (pure Nim)", bold = true)
  result.add label(380, 306, "session: eval, complete, inspect, interrupt, reset", 11.5, color = quiet)
  for i, name in backends:
    result.add box(64 + i * 216, 320, 200, 32, fill = tint, sw = 1)
    result.add label(164 + i * 216, 340, name, 11.5)
  result.add arrow(380, 368, 398)
  result.add &"""<text x="392" y="388" font-size="11.5" style="fill: {quiet}">pipe</text>"""
  result.add box(left, 400, wide, 56)
  result.add label(380, 424, "Worker process", bold = true)
  result.add label(380, 441, "runs the user code and holds its state; killed and restarted on a crash or interrupt", 11.5, color = quiet)
  result.add "</svg>"
