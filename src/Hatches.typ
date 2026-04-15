

/// Built-in material hatch pattern: Bricks
#let bricks-fill = tiling(size: (40pt, 20pt))[
  #let stroke-style = 0.6pt 
  #std.place(std.line(start: (0pt, 0pt), end: (40pt, 0pt), stroke: stroke-style))
  #std.place(std.line(start: (0pt, 10pt), end: (40pt, 10pt), stroke: stroke-style))
  #std.place(std.line(start: (0pt, 0pt), end: (0pt, 10pt), stroke: stroke-style))
  #std.place(std.line(start: (20pt, 10pt), end: (20pt, 20pt), stroke: stroke-style))
]

/// Built-in material hatch pattern: Diagonal Lines
#let hatch-fill = tiling(size: (10pt, 10pt))[
  #std.line(start: (0pt, 0pt), end: (10pt, 10pt), stroke: 0.5pt + black)
]

/// Built-in material hatch pattern: Grass
#let grass-fill = tiling(size: (5pt, 8pt))[
  #std.rotate(270deg)[
  #text(fill: green)[#sym.prec]]
]
