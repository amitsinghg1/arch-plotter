#import "@preview/cetz:0.4.2"
#import cetz.draw: *
#import cetz.vector

#import "Furniture.typ": *

// A dedicated canvas for interior architecture and floor plans
#let arch-canvas(scale: 0.5cm, body) = {
  cetz.canvas(length: scale, body,)
}

/// --- 1. UNIT HELPERS (FEET & INCHES) ---

// Helper to convert Feet + Inches to Decimal Feet
// Usage: ft(5, 6) -> 5.5
#let ft(feet, inches) = {
  feet + (inches / 12.0)
}

// Converts Meters into Decimal Feet
// Usage: m(2) -> 6.561... (Allows you to type metric into your feet-based grid)
#let m(meters) = {
  meters / 0.3048
}

// Converts Centimeters into Decimal Feet
#let cm(centimeters) = {
  centimeters / 30.48
}

/// --- 2. SMART DISPLAY FORMATTER ---
// Takes a distance in feet and formats it as text.
// unit-system: "metric" (m/cm) or "imperial" (feet/inches)
#let format-dist(dist-in-feet, unit-system: "imperial") = {
  if unit-system == "metric" {
    // 1. Convert the feet to meters mathematically
    let meters = dist-in-feet * 0.3048
    
    // 2. Display logic (>= 1m shows meters, < 1m shows cm)
    if meters >= 1.0 {
      str(calc.round(meters, digits: 2)) + " m"
    } else {
      str(calc.round(meters * 100, digits: 1)) + " cm"
    }
    
  } else {
    // IMPERIAL LOGIC (Your exact original code)
    let total-inches = calc.round(dist-in-feet * 12 * 4) / 4
    let feet = calc.floor(total-inches / 12)
    let rest-inches = calc.rem(total-inches, 12)
    let inch-whole = calc.floor(rest-inches)
    let quarters = calc.round((rest-inches - inch-whole) * 4) // Fixed rounding issue
    
    let fraction = if quarters == 1 { [ $1/4$] } 
      else if quarters == 2 { [ $1/2$] } 
      else if quarters == 3 { [ $3/4$] } 
      else { [] }
    
    str(feet) + "'" + str(inch-whole) + fraction + "\""
  }
}


/// --- HELPER FUNCTIONS ---

// Fix: Calculate angle manually using standard Typst math
#let get-angle(v) = {
  // calc.atan2(x, y) returns the angle of the vector relative to X-axis
  calc.atan2(v.at(0), v.at(1))
}

// Helper: Calculates the perpendicular shift based on alignment
#let get-align-dy(align, thickness) = {
  if align == "left" { thickness / 2 } 
  else if align == "right" { -thickness / 2 } 
  else { 0 }
}

/// --- ARCHITECTURAL ELEMENTS ---

// --- 2. Improved Wall Shape (With Override Support) ---
#let wall-shape(from, to, thickness: 0.75, shift: 0, join: "", stroke: none, fill: black, ext-start: auto, ext-end: auto) = {
  let v = vector.sub(to, from)
  let angle = get-angle(v)
  let len = vector.len(v)

  // Extension Logic: Use manual overrides if provided, otherwise use standard 90-degree math
  let actual-ext-start = if ext-start != auto { ext-start } else if join == "start" or join == "both" { thickness / 2 } else { 0 }
  let actual-ext-end   = if ext-end != auto { ext-end } else if join == "end" or join == "both" { thickness / 2 } else { 0 }

  let x-start = -actual-ext-start
  let x-end   = len + actual-ext-end

  group({
    translate(from)
    rotate(angle)
    translate((0, shift)) 

    rect(
      (x-start, -thickness/2), 
      (x-end, thickness/2), 
      stroke: stroke,
      fill: fill
    )
  })
}

//THE MARK COMMAND
#let Mark(name) = (type: "mark", name: name)

// Draw a wall directly to a previously saved mark
#let GoToMark(name, ..args) = (type: "go-to-mark", name: name, args: args.named())

// Lift the pen and teleport to a saved mark (creates a new starting point for a wall)
#let JumpToMark(name) = (type: "jump-to-mark", name: name)

// UPDATED DRAW-WALLS (Supports Overrides AND Simple Lines)
#let draw-walls(wall-data, default-thickness: 0.75, border-width: 0.02, wall-color: white) = {
  let walls-list = if type(wall-data) == dictionary { wall-data.walls } else { wall-data }
  
  let get-shift(t, align) = {
    if align == "left" { t / 2 } 
    else if align == "right" { -t / 2 } 
    else { 0 }
  }

  // PASS 1: The Border (Skip simple lines here)
  group({
    for w in walls-list {
      // NEW: If this segment is tagged as a line, skip the thick border
      if w.at("style", default: "wall") == "line" { continue }
      
      let t = w.at("thickness", default: default-thickness)
      let align = w.at("align", default: "center")
      let total-shift = w.at("shift", default: 0.0) + get-shift(t, align)
      
      let e-start = w.at("ext-start", default: auto)
      let e-end = w.at("ext-end", default: auto)
      
      wall-shape(w.from, w.to, thickness: t + (border-width * 2), shift: total-shift, join: w.at("join", default: ""), fill: black, ext-start: e-start, ext-end: e-end, stroke: (join:"bevel", cap:"round"))
    }
  })

  // PASS 2: The Fill (And drawing the simple lines)
  group({
    for w in walls-list {
      // NEW: Draw a simple line if tagged
      if w.at("style", default: "wall") == "line" {
        let line-stroke = w.at("stroke", default: 1pt + black)
        line(w.from, w.to, stroke: line-stroke)
        continue // Move to the next segment
      }
      
      let t = w.at("thickness", default: default-thickness)
      let align = w.at("align", default: "center")
      let total-shift = w.at("shift", default: 0.0) + get-shift(t, align)
      
      let e-start = w.at("ext-start", default: auto)
      let e-end = w.at("ext-end", default: auto)

      wall-shape(w.from, w.to, thickness: t, shift: total-shift, join: w.at("join", default: ""), fill: wall-color, ext-start: e-start, ext-end: e-end)
    }
  })
}

/// --- 2-WAY SHIFT N-SIDED COLUMN ---
// sides: 4 (Square), 6 (Hexagon), 30+ (Circle)
#let column(pos, size: 0.75, sides: 4, fill: black, align: "center", angle: 0deg, shift: (0, 0)) = {
  
  let (sx, sy) = if type(shift) == array { 
    (shift.at(0), shift.at(1)) 
  } else { 
    (0, shift) 
  }

  let align-dy = if align == "left" { size / 2 } 
  else if align == "right" { -size / 2 } 
  else { 0 }
  
  let final-dx = sx
  let final-dy = align-dy + sy

  group({
    translate(pos)
    rotate(angle)
    translate((final-dx, final-dy))

    if sides == 4 {
      // Standard Square
      rect((-size/2, -size/2), (size/2, size/2), fill: fill, stroke: none)
      
    } else if sides >= 30 {
      // Perfect Circle (radius is exactly half the size)
      circle((0,0), radius: size/2, fill: fill, stroke: none)
      
    } else {
      // Custom Polygon (Hexagon, Octagon, etc.)
      let pts = ()
      
      // THE FIX: Calculate the exact outer radius needed to keep the flat sides at 'size'
      let r = (size / 2) / calc.cos(180deg / sides)
      
      // Offset so the flat edge sits perfectly parallel to the wall
      let offset = -90deg - (180deg / sides) 
      
      for i in range(sides) {
        let a = offset + (i * 360deg / sides)
        pts.push((r * calc.cos(a), r * calc.sin(a)))
      }
      
      line(..pts, close: true, fill: fill, stroke: none)
    }
  })
}

// 3. IMPROVED DOOR FUNCTION
// hinge: "left" or "right" (Horizontal flip)
// swing: "out" or "in"     (Vertical flip / Top vs Bottom)
// label: content to display on the door (NEW PARAMETER)
#let door(from, to, dist, width: 3.0, hinge: "left", swing: "in", open: 90deg, thickness: 0.75, align: "center", label: none, label-offset:(0,0)) = {
  let v = vector.sub(to, from)
  let angle = calc.atan2(v.at(0), v.at(1))
  let pos = vector.add(from, vector.scale(vector.norm(v), dist))
  let dy = get-align-dy(align, thickness) // <--- 2. Calculate offset

  group({
    translate(pos)
    rotate(angle)
    translate((0, dy)) // <--- 3. Apply offset

    // A. The Eraser (Always the same)
    rect((-width/2, -(thickness + 0.15)/2), (width/2, (thickness + 0.15)/2), fill: white, stroke: none,)

    // B. The Frame (Always the same)
    let f = 0.15
    rect((-width/2, -thickness/2), (-width/2 + f, thickness/2), fill: black) 
    rect((width/2 - f, -thickness/2), (width/2, thickness/2), fill: black)

    // C. DYNAMIC FLIPPING LOGIC
    // 1. Calculate Hinge Position (Pivot Point)
    let hx = if hinge == "left" { -width/2 } else { width/2 }
    let hy = if swing == "out"  { thickness/2 } else { -thickness/2 }

    // 2. Calculate Angles
    // "Base" angle is the door's closed position (0deg for Left, 180deg for Right)
    let start-angle = if hinge == "left" { 0deg } else { 180deg }
    
    // "Direction" determines if we rotate Clockwise (-1) or Counter-Clockwise (1)
    // Left-Out (+), Right-In (+)  |  Right-Out (-), Left-In (-)
    let is-left = (hinge == "left")
    let is-out  = (swing == "out")
    let dir = if is-left == is-out { 1 } else { -1 }
    
    // The actual sweep angle for the arc
    let delta = open * dir

    // D. DRAW
    // 1. The Arc
    arc((-hx, hy), radius: width, start: start-angle, delta: delta, mode: "OPEN", stroke: (dash: "dotted", thickness: 1.5pt))

    // 2. The Panel
    // We move to the hinge, rotate to the open angle, and draw the panel
    group({
      translate((hx, hy))
      rotate(start-angle + delta)
      
      // Draw the panel extending from (0,0) along the X-axis
      // Using a thin rect allows it to have thickness like a real door
      rect((0, -0.05), (width, 0.05), fill: white, stroke: 1pt)

      // NEW: Place content on the door center
      // We calculate center of width (width/2) and center of thickness (0)
      if label != none {
        content((width/2-label-offset.at(0), width/2-label-offset.at(1)), label, anchor: "center")
      }
    })
  })
}

/// --- FIXED DOUBLE DOOR ---
#let double-door(from, to, dist, width: 3.0, swing: "out", open: 90deg, thickness: 0.75, align: "center", label:none) = {
  let v = vector.sub(to, from)
  let angle = calc.atan2(v.at(0), v.at(1))
  let pos = vector.add(from, vector.scale(vector.norm(v), dist))
  let dy = get-align-dy(align, thickness)

  group({
    translate(pos)
    rotate(angle)
    translate((0, dy))

    // 1. Eraser & Frame
    rect((-width/2, -(thickness + 0.05)/1.8), (width/2, (thickness + 0.05)/1.7), fill: white, stroke: none)
    
    let f = 0.15
    rect((-width/2, -thickness/2), (-width/2 + f, thickness/2), fill: black) 
    rect((width/2 - f, -thickness/2), (width/2, thickness/2), fill: black)

    // 2. Leaf Configuration
    let leaf-w = width / 2
    let hy = if swing == "out" { thickness/2 } else { -thickness/2 }
    
    // --- LEFT LEAF ---
    // Hinge: Left edge (-width/2)
    // Start Angle: 0 deg (Pointing Center)
    let hx-left = -width/2
    let dir-left = if swing == "out" { 1 } else { -1 } // 1=CCW (Up), -1=CW (Down)
    let delta-left = open * dir-left
    
    // Left Arc
    arc((-hx-left/1000, hy), radius: leaf-w, start: 0deg, delta: delta-left, mode: "OPEN", stroke: (dash: "dotted", thickness: 1pt))
    
    // Left Panel
    group({
      translate((hx-left, hy))
      rotate(0deg + delta-left)
      rect((0, -0.05), (leaf-w, 0.05), fill: white, stroke: 1pt)
    })

    // --- RIGHT LEAF ---
    // Hinge: Right edge (+width/2)
    // Start Angle: 180 deg (Pointing Center)
    let hx-right = width/2
    let dir-right = if swing == "out" { -1 } else { 1 } // -1=CW (Up), 1=CCW (Down)
    let delta-right = open * dir-right
    
    // Right Arc
    // Note: We explicitly use delta to force the correct direction
    arc((-hx-right/2000, hy), radius: leaf-w, start: 180deg, delta: delta-right, mode: "OPEN", stroke: (dash: "dotted", thickness: 1pt))
    
    // Right Panel
    group({
      translate((hx-right, hy))
      rotate(180deg + delta-right)
      rect((0, -0.05), (leaf-w, 0.05), fill: white, stroke: 1pt)
    })
    // NEW: Place content on the door center
      // We calculate center of width (width/2) and center of thickness (0)
      if label != none {
        content((width/2-1, 0), label, anchor: "center")
      }
  })
}

/// --- OPENING FUNCTION WITH LABEL ---
#let opening(
  from, 
  to, 
  dist, 
  width: 3.0, 
  style: "empty", 
  thickness: 0.75, 
  align: "center", 
  shift: 0.0,
  label: none,         // New: The text/content to display
  label-offset: 0.8,
  stroke: 1pt// New: Vertical offset for the label
) = {
  let v = vector.sub(to, from)
  let angle = calc.atan2(v.at(0), v.at(1))
  let pos = vector.add(from, vector.scale(vector.norm(v), dist))
  let dy = get-align-dy(align, thickness)

  group({
    translate(pos)
    rotate(angle)
    translate((0, dy))

    // 1. Eraser & Frame (Always Centered)
    rect((-width/2, -(thickness + 0.05)/1.7), (width/2, (thickness + 0.05)/1.7), fill: white, stroke: none)
    
    let f = 0.01
    rect((-width/2, -thickness/2), (-width/2 + f, thickness/2), fill: black) 
    rect((width/2 - f, -thickness/2), (width/2, thickness/2), fill: black)

    // 2. Style Logic with SHIFT
    if style != "empty" {
      group({
        translate((0, shift))
        
        if style == "line" {
          line((-width/2, 0), (width/2, 0), stroke: stroke,)
        } 
        else if style == "rect" {
          rect((-width/2, -thickness/2), (width/2, thickness/2), stroke: stroke, )
        }else if style == "cross" {
          // We wrap these in an array and use explicit black stroke
          line((-width/2, -thickness/2), (width/2, thickness/2), stroke: stroke)
          line((-width/2, thickness/2), (width/2, -thickness/2), stroke: stroke,)
        }
      })
    }

    // 3. Label Logic
    if label != none {
      // We place the label at (0, label-offset)
      // anchor: "center" ensures it stays perfectly middle-aligned
      content((0, label-offset), label, anchor: "center")
    }
  })
}


// 4. WINDOW FUNCTION (Sticks to wall)
#let window(
  wall-start, 
  wall-end, 
  dist, 
  width: 1.0, 
  thickness: 0.75, 
  align: "center", 
  label: none,         // New argument
  label-offset: 0.8    // Optional: distance from the center
) = {
  let v = vector.sub(wall-end, wall-start)
  let angle = get-angle(v)
  let pos = vector.add(wall-start, vector.scale(vector.norm(v), dist))
  let dy = get-align-dy(align, thickness)

  group({
    translate(pos)
    rotate(angle)
    translate((0, dy))

    // A. The "Eraser" (Clears the wall line behind the window)
    rect((-width/2, -(thickness + 0.01)/2), (width/2, (thickness + 0.01)/2), fill: white, stroke: none)
    
    // B. Wall caps (sides of window)
    line((-width/2, -thickness/2), (-width/2, thickness/2), stroke: 1pt)
    line((width/2, -thickness/2), (width/2, thickness/2), stroke: 1pt)
    
    // C. Window Glass / Frame lines
    let offset = thickness / 4
    line((-width/2, -offset), (width/2, -offset), stroke: 0.5pt)
    line((-width/2, offset), (width/2, offset), stroke: 0.5pt)

    // D. Label
    if label != none {
      // We place the content at (0, label-offset) 
      // This keeps the text readable and slightly offset from the glass lines
      content((0, label-offset), text(size: 8pt, label))
    }
  })
}

/// --- MULTI-TURN STAIRS FUNCTION ---
// steps: integer (12) OR array (3, 5, 3)
// turn: "right" (Spiral/U-shape) OR "left" OR array ("left", "right") for zigzag
#let stairs(pos, steps: 12, width: 3.0, run: 0.75, angle: 0deg, turn: "right", split-landing: false) = {
  
  // 1. Normalize 'steps' to an array (e.g., 12 -> (12,))
  let runs = if type(steps) == array { steps } else { (steps,) }
  
  // 2. Normalize 'turn' to an array (e.g., "right" -> ("right", "right", ...))
  // This allows for complex shapes like Zig-Zags if needed
  let turns = if type(turn) == array { turn } else { range(runs.len()).map(_ => turn) }

group({
  translate(pos)
  rotate(angle) // Global rotation

  // 3. Loop through every "Run" of steps
  for (i, count) in runs.enumerate() {
    let is-last = (i == runs.len() - 1)
    let len = count * run
      
    // A. Draw The Treads (Steps)
  for k in range(count) {
    rect((0, k*run), (width, (k+1)*run), stroke: 0.8pt)
      }

  // B. Draw The Arrow Segment for this Run
  // - If First Run: Arrow starts at bottom (0)
  // - If Middle Run: Arrow starts from previous landing center (-width/2)
  let start-y = if i == 0 { 0 } else { -width/2 }
      
  // - If Last Run: Arrow ends at top of steps (len)
  // - If Middle Run: Arrow goes to center of next landing (len + width/2)
  let end-y = if is-last { len } else { len + width/2 }
      
  // - Only put the arrow tip ">" on the very last segment
  let mark = if is-last { (end: ">>") } else { none }
      
  line((width/2, start-y), (width/2, end-y), mark: mark, stroke: 0.8pt)
      
  // Label "UP" only at the start
  if i == 0 {
  content((width/2+0.6, 0.4), text(size: 0.6em, fill: black)[UP], anchor: "south")
      }

  // C. Handle The Turn (If not the last run)
  if not is-last {
   // Identify the turn direction early to determine landing split
  let current-turn = turns.at(calc.rem(i, turns.len()))

  // 1. Draw the Landing
  rect((0, len), (width, len + width), stroke: 0.8pt)
        
  // OPTIONAL: Draw a diagonal line on the landing if split-landing is true
// The diagonal flips based on whether the turn is "left" or "right"
  if split-landing {
    if current-turn == "right" {
  // Right Turn: Line from Top-Left to Bottom-Right
  line((0, len + width), (width, len), stroke: 0.8pt)
  } else {
  // Left Turn: Line from Bottom-Left to Top-Right
  line((0, len), (width, len + width), stroke: 0.8pt)
   }
  }
        
// 2. Transform Coordinate System for the Next Run
//    Logic: Move to landing center -> Rotate -> Move to edge to start new run
let rot-dir = if current-turn == "right" { -1 } else { 1 }

translate((width/2, len + width/2)) // Move to Center of Landing
  rotate(90deg * rot-dir)             // Rotate
  translate((-width/2, width/2))      // Reset origin to bottom-left of new run
      }
    }
  })
}

// Calculate the exact distance between any two points
#let get-length(p1, p2) = {
  let dx = p2.at(0) - p1.at(0)
  let dy = p2.at(1) - p1.at(1)
  calc.sqrt((dx * dx) + (dy * dy))
}

//Creates dimension from two points
#let dim(from, to, offset: 2.0, label: auto, show-line: true, size:8pt, shift: (0,0), units:"imperial") = {
  // --- NEW SHIFT LOGIC (Does not break sensitive drawing code) ---
  // We calculate new 'from' and 'to' points BEFORE the drawing logic runs.
  // shift.at(0) moves the Start IN. shift.at(1) moves the End IN.
  let v-orig = vector.sub(to, from)
  let dist-orig = vector.len(v-orig)
  
  // Create Unit Vector (Direction)
  let u = if dist-orig != 0 { vector.scale(v-orig, 1/dist-orig) } else { (0,0) }
  
  // Apply the shift
  // Add to Start, Subtract from End
  let from = vector.add(from, vector.scale(u, shift.at(0)))
  let to   = vector.add(to, vector.scale(u, -shift.at(1)))
  // -------------------------------------------------------------

  // ORIGINAL CODE (Untouched Logic)
  let v = vector.sub(to, from)
  let dist = vector.len(v)
  let angle = get-angle(v)
  let is-flipped = angle > 90deg or angle < -90deg
  
  group({
    translate(from); rotate(angle); translate((0, offset))
    
    // Toggle the line and marks
    if show-line {
      line((0, 0), (dist, 0), mark: (start: "|", end: "|"), stroke: 0.25pt)
    }
    
    content((dist/2, 0), angle: if is-flipped { angle+180deg } else { angle }, {
        let txt = if label == auto { format-dist(dist, unit-system: units) } else { label }
        box(fill: white, inset: 0.5pt, text(size: size, txt))
    })
  })
}

//Get area for given vertices
#let get-area(vertices) = {
  // valid-check: Ensure we actually have a list of points
  if type(vertices) != array or vertices.len() < 3 { return 0.0 }
  
  let n = vertices.len()
  let sum = 0.0
  for i in range(n) {
    let current = vertices.at(i)
    let next = vertices.at(calc.rem(i + 1, n)) 
    sum = sum + (current.at(0) * next.at(1) - next.at(0) * current.at(1))
  }
  return 0.5 * calc.abs(sum)
}

// NEW: Formats the raw square feet into display text
#let format-area(sq-feet, unit-system: "imperial") = {
  if unit-system == "metric" {
    // Conversion: 1 Square Foot = 0.092903 Square Meters
    let sq-meters = sq-feet * 0.092903
    str(calc.round(sq-meters, digits: 2)) + " sq.m"
  } else {
    str(calc.round(sq-feet, digits: 2)) + " sq.ft"
  }
}

/// --- 2. SMART POLYGON ROOM ---
/// --- UTILITY: Decimal Feet to Arch String ---

// --- 1. MATH HELPERS FOR INSETTING ---
// (Paste these before poly-room)

#let intersect-lines(p1, v1, p2, v2) = {
  let det = v1.at(0) * v2.at(1) - v1.at(1) * v2.at(0)
  if calc.abs(det) < 0.0001 { return p1 } // Parallel safety
  
  let dx = p2.at(0) - p1.at(0)
  let dy = p2.at(1) - p1.at(1)
  let t = (dx * v2.at(1) - dy * v2.at(0)) / det
  
  (p1.at(0) + t * v1.at(0), p1.at(1) + t * v1.at(1))
}

#let inset-polygon(pts, widths) = {
  let n = pts.len()
  let new-pts = ()
  let lines = ()
  
  // 1. Shift every line inward
  for i in range(n) {
    let p-curr = pts.at(i)
    let p-next = pts.at(calc.rem(i + 1, n))
    // Cycle through widths if fewer are provided than walls
    let w = widths.at(calc.rem(i, widths.len())) 
    
    let dx = p-next.at(0) - p-curr.at(0)
    let dy = p-next.at(1) - p-curr.at(1)
    let dist = calc.sqrt(dx*dx + dy*dy)
    
    // Normal vector (inward for Counter-Clockwise points)
    let nx = -dy / dist
    let ny = dx / dist
    
    lines.push((
      start: (p-curr.at(0) + nx*w, p-curr.at(1) + ny*w),
      dir: (dx, dy)
    ))
  }
  
  // 2. Find new intersections
  for i in range(n) {
    let l1 = lines.at(calc.rem(i - 1 + n, n))
    let l2 = lines.at(i)
    new-pts.push(intersect-lines(l1.start, l1.dir, l2.start, l2.dir))
  }
  return new-pts
}


// --- 2. IMPROVED POLY-ROOM FUNCTION ---
// New Parameter: wall-widths (array of floats)
#let poly-room(pts, name, wall-widths: none, show-area: true, show-dim: true, stroke: 1pt, shift: (0, 0), size:9pt, fill: luma(240).transparentize(80%), units:"imperial") = {
  
  // A. Data Cleaning (Handle flat arrays)
  let points = if type(pts.at(0)) == int or type(pts.at(0)) == float {
    let new-v = ()
    for i in range(0, pts.len(), step: 2) {
       if i + 1 < pts.len() { new-v.push((pts.at(i), pts.at(i+1))) }
    }
    new-v
  } else { pts }

  // B. Determine Render Points (Inner vs Outer)
  let render-pts = if wall-widths != none {
    inset-polygon(points, wall-widths)
  } else {
    points
  }

  // C. Calculate Stats using RENDER POINTS (The inner shape)
  let cx = 0.0; let cy = 0.0
  let min-x = render-pts.at(0).at(0); let max-x = render-pts.at(0).at(0)
  let min-y = render-pts.at(0).at(1); let max-y = render-pts.at(0).at(1)

  for p in render-pts { 
    cx += p.at(0); cy += p.at(1)
    if p.at(0) < min-x { min-x = p.at(0) }
    if p.at(0) > max-x { max-x = p.at(0) }
    if p.at(1) < min-y { min-y = p.at(1) }
    if p.at(1) > max-y { max-y = p.at(1) }
  }

  // Centroid & Dims
  let center-base = (cx / render-pts.len(), cy / render-pts.len())
  let width = max-x - min-x
  let height = max-y - min-y

  // D. Shift Logic
  let (sx, sy) = if type(shift) == array { 
    (shift.at(0), shift.at(1)) 
  } else { 
    (0, shift) 
  }
  let text-pos = (center-base.at(0) + sx, center-base.at(1) + sy)

  // E. Draw Boundary
  // Note: We fill the calculated shape (inner if widths provided)
  line(..render-pts, close: true, fill: fill, stroke: stroke)
  
  // Optional: Draw original boundary faintly if insetting
  if wall-widths != none {
     // line(..points, close: true, stroke: (dash: "dotted", thickness: 0.5pt, paint: gray))
  }

  // F. Draw Label
  content(text-pos, align(center)[ 
    #text(weight: "bold", name) \ #v(-0.5em)
    
    #if show-dim {
      let w-str = format-dist(width, unit-system: units)
      let h-str = format-dist(height, unit-system:units)
      text(size: size, fill: black, w-str + $times$ + h-str)
      if show-area { linebreak() } 
    }
    #v(-0.7em)
    #if show-area {
      // 2. USE THE NEW AREA FORMATTER HERE
      let area-val = get-area(render-pts)
      text(size: size, fill: black, format-area(area-val, unit-system: units))
    }
  ])
}

/// --- OPEN TO SKY (O.T.S) / SHAFT FUNCTION ---
// Takes an array of points and draws an "X" across them.
#let ots(pts, name: "O.T.S", wall-widths: none, show-area: false, show-dim: false, stroke: 0.5pt, size: 9pt, shift: (0, 0), units: "imperial", fill: none) = {
  
  // 1. Data Cleaning
  let points = if type(pts.at(0)) == int or type(pts.at(0)) == float {
    let new-v = ()
    for i in range(0, pts.len(), step: 2) {
       if i + 1 < pts.len() { new-v.push((pts.at(i), pts.at(i+1))) }
    }
    new-v
  } else { pts }

  // 2. Determine Render Points (Inner vs Outer bounds)
  let render-pts = if wall-widths != none {
    inset-polygon(points, wall-widths)
  } else {
    points
  }

  // 3. Calculate the Bounding Box & Center using RENDER POINTS
  let min-x = render-pts.at(0).at(0); let max-x = render-pts.at(0).at(0)
  let min-y = render-pts.at(0).at(1); let max-y = render-pts.at(0).at(1)

  for p in render-pts { 
    if p.at(0) < min-x { min-x = p.at(0) }
    if p.at(0) > max-x { max-x = p.at(0) }
    if p.at(1) < min-y { min-y = p.at(1) }
    if p.at(1) > max-y { max-y = p.at(1) }
  }
  
  let cx = (min-x + max-x) / 2
  let cy = (min-y + max-y) / 2
  let width = max-x - min-x
  let height = max-y - min-y

  // 4. Shift Logic
  let (sx, sy) = if type(shift) == array { 
    (shift.at(0), shift.at(1)) 
  } else { 
    (0, shift) 
  }
  let text-pos = (cx + sx, cy + sy)

  group({
    // 5. Draw the Outer Boundary
    line(..render-pts, close: true, stroke: stroke, fill: fill)
    
    // 6. Draw the Cross (X) perfectly fitted to the inner walls
    if render-pts.len() == 4 {
      line(render-pts.at(0), render-pts.at(2), stroke: stroke)
      line(render-pts.at(1), render-pts.at(3), stroke: stroke)
    } else {
      line((min-x, min-y), (max-x, max-y), stroke: stroke)
      line((min-x, max-y), (max-x, min-y), stroke: stroke)
    }

    // 7. Draw the Label with Dimensions and Area
    content(text-pos, box(fill: white, inset: 2pt, align(center)[ 
      #text(weight: "bold", size: size, name) 
      
      #if show-dim {
        linebreak()
        v(-2.7em)
        let w-str = format-dist(width, unit-system: units)
        let h-str = format-dist(height, unit-system: units)
        text(size: size, fill: black, w-str + $times$ + h-str)
      }
      
      #if show-area {
        linebreak()
        v(-2.7em)
        let area-val = get-area(render-pts)
        text(size: size, fill: black, format-area(area-val, unit-system: units))
      }
    ]))
  })
}


/// --- GRID SYSTEM HELPERS ---

// 1. GENERATE GRID
// Takes a dictionary of X positions and Y positions
// Returns a function 'get-node(x-key, y-key)'
#let create-grid(x-grids, y-grids) = {
  return (x-key, y-key) => {
    let x = x-grids.at(x-key)
    let y = y-grids.at(y-key)
    (x, y)
  }
}

// 2. RELATIVE MOVER
// Moves a point relative to a grid intersection
// Usage: rel("A-1", dx: 0.5, dy: -0.75)
#let move(pt, dx: 0, dy: 0) = {
  (pt.at(0) + dx, pt.at(1) + dy)
}


/// --- ADVANCED INTERNAL DIMENSION HELPER ---
// thick-start: How much to shrink from the 'from' point (e.g. 0.75)
// thick-end:   How much to shrink from the 'to' point (e.g. 0.375)
// offset:      Distance to move the dimension line sideways
#let i-dim(from, to, thick-start: 0.75, thick-end: 0.75, offset: 0, size:8pt) = {
  
  // 1. Calculate direction vector of the wall/room
  let v = vector.sub(to, from)
  let dist = vector.len(v)
  
  // Safety check to avoid division by zero
  if dist == 0 { return }

  // 2. Normalize vector (length 1) to determine direction
  let dir = vector.scale(v, 1/dist)
  
  // 3. Shift START Point 'IN' by thick-start
  // Moves in the direction of the line
  let start-shift = vector.scale(dir, thick-start)
  let new-from = vector.add(from, start-shift)
  
  // 4. Shift END Point 'BACK' by thick-end
  // Moves opposite to the direction of the line
  let end-shift = vector.scale(dir, -thick-end)
  let new-to = vector.add(to, end-shift)
  
  // 5. Draw the dimension
  dim(new-from, new-to, offset: offset, label: auto, size:size)
}


/// --- ADVANCED TRACING ENGINE ---

// Command Helpers with parameter support
#let R(len, ..args) = (type: "move", d: (len, 0), args: args.named())
#let L(len, ..args) = (type: "move", d: (-len, 0), args: args.named())
#let U(len, ..args) = (type: "move", d: (0, len), args: args.named())
#let D(len, ..args) = (type: "move", d: (0, -len), args: args.named())
#let A(angle, len, ..args) = (type: "move", d: (
  calc.cos(angle) * len, 
  calc.sin(angle) * len
), args: args.named())

// --- 2. Advanced Intersections (Drop) ---
// Drop at Y direction till the intersecting point
#let DropY(p1, p2, ..args) = (type: "drop-y", p1: p1, p2: p2, args: args.named())

// Drop at X direction till the intersecting point
#let DropX(p1, p2, ..args) = (type: "drop-x", p1: p1, p2: p2, args: args.named())

// --- Directional Jumps (Lift pen, move X distance) ---
#let JR(len) = (type: "jump", d: (len, 0))
#let JL(len) = (type: "jump", d: (-len, 0))
#let JU(len) = (type: "jump", d: (0, len))
#let JD(len) = (type: "jump", d: (0, -len))

// NEW: Jump at a specific angle!
#let JA(angle, len) = (type: "jump", d: (calc.cos(angle) * len, calc.sin(angle) * len))

// --- Advanced Intersections (Jump / Lift Pen) ---
// Jumps in the Y direction until intersecting the line, without drawing a wall
#let JDropY(p1, p2) = (type: "jump-drop-y", p1: p1, p2: p2)

// Jumps in the X direction until intersecting the line, without drawing a wall
#let JDropX(p1, p2) = (type: "jump-drop-x", p1: p1, p2: p2)

// --- Teleport to (0,0) relative to trace start ---
#let Home() = (type: "home", d: (0,0))

#let Mark(name) = (type: "mark", name: name)

// --- ADD THIS TO YOUR COMMAND HELPERS ---
#let C(..args) = (type: "close", d: (0,0), args: args.named())

#let trace-walls(start: (0,0), ops, ..global-args) = {
  let current = start
  let walls = ()
  let anchors = (start: start) // The engine's live memory!
  
  for op in ops {
    let args = op.at("args", default: (:))
    
    // Logic A: Save the memory and skip drawing
    if op.type == "mark" {
      anchors.insert(op.name, current)
      continue
    }

    // Logic B: Calculate Movement Delta
    let delta = if op.type == "home" or op.type == "close" {
      (start.at(0) - current.at(0), start.at(1) - current.at(1))
    }else if op.type == "drop-y" or op.type == "jump-drop-y" {
      let x = current.at(0)
      
      let p1 = if type(op.p1) == str { anchors.at(op.p1, default: (0,0)) } else { op.p1 }
      let p2 = if type(op.p2) == str { anchors.at(op.p2, default: (0,0)) } else { op.p2 }
      
      let (x1, y1) = p1
      let (x2, y2) = p2
      let target-y = if x1 == x2 { y1 } else { y1 + (y2 - y1) * (x - x1) / (x2 - x1) }
      (0, target-y - current.at(1))
      
    // INTERSECTION MATH: DropX & JumpDropX
    } else if op.type == "drop-x" or op.type == "jump-drop-x" {
      let y = current.at(1)
      
      let p1 = if type(op.p1) == str { anchors.at(op.p1, default: (0,0)) } else { op.p1 }
      let p2 = if type(op.p2) == str { anchors.at(op.p2, default: (0,0)) } else { op.p2 }
      
      let (x1, y1) = p1
      let (x2, y2) = p2
      let target-x = if y1 == y2 { x1 } else { x1 + (x2 - x1) * (y - y1) / (y2 - y1) }
      (target-x - current.at(0), 0)} else if op.type == "drop-y" {
      let x = current.at(0)
      
      // NEW: Check if p1 and p2 are Mark names (strings) or coordinates
      let p1 = if type(op.p1) == str { anchors.at(op.p1, default: (0,0)) } else { op.p1 }
      let p2 = if type(op.p2) == str { anchors.at(op.p2, default: (0,0)) } else { op.p2 }
      
      let (x1, y1) = p1
      let (x2, y2) = p2
      let target-y = if x1 == x2 { y1 } else { y1 + (y2 - y1) * (x - x1) / (x2 - x1) }
      (0, target-y - current.at(1))
      
    // INTERSECTION MATH: DropX
    } else if op.type == "drop-x" {
      let y = current.at(1)
      
      // NEW: Check if p1 and p2 are Mark names (strings) or coordinates
      let p1 = if type(op.p1) == str { anchors.at(op.p1, default: (0,0)) } else { op.p1 }
      let p2 = if type(op.p2) == str { anchors.at(op.p2, default: (0,0)) } else { op.p2 }
      
      let (x1, y1) = p1
      let (x2, y2) = p2
      let target-x = if y1 == y2 { x1 } else { x1 + (x2 - x1) * (y - y1) / (y2 - y1) }
      (target-x - current.at(0), 0)}
      
      else if op.type == "go-to-mark" or op.type == "jump-to-mark" {
      // Look up the coordinate in live memory!
      if op.name in anchors {
        let pt = anchors.at(op.name)
        (pt.at(0) - current.at(0), pt.at(1) - current.at(1))
      } else {
        (0, 0) // Failsafe if mark doesn't exist
      }
    } else {
      op.d
    }
    
    // Logic C: Define Segment Points
    let wall-from = current
    let wall-to = (current.at(0) + delta.at(0), current.at(1) + delta.at(1))
    
    // Logic D: Draw physical walls (Moves, Closes, and GoToMarks)
    // Jumps are ignored here, they just update the 'current' tracker
    let is-draw = op.type == "move" or op.type == "close" or op.type == "go-to-mark" or op.type == "drop-x" or op.type == "drop-y"
    
    if is-draw {
      let props = global-args.named() + args
      walls.push((from: wall-from, to: wall-to, ..props))
    }
    
    // Update cursor position for the next instruction
    current = wall-to
  }
  
  (walls: walls, anchors: anchors)
}


// 2. Helper to extract points from a list of walls
// Usage: get-pts( wall.slice(4, 7) )
#let get-pts(wall-list) = {
  if wall-list.len() == 0 { return () }
  // Start with the 'from' point of the first wall
  let pts = (wall-list.first().from,)
  // Add the 'to' point of every wall
  for w in wall-list {
    pts.push(w.to)
  }
  return pts
}


/// --- PRINT MARKS UTILITY ---
// trace-data: The result object returned from your trace() function
// size: Text size for the label
// color: Color of the marker and text
// offset: (x, y) Shift the text slightly away from the exact point (default slightly up-right)
#let print-marks(trace-data, size: 13pt, color: blue, offset: (0.3, 0.2)) = {
  // 1. Safety check
  if type(trace-data) != dictionary or "anchors" not in trace-data { return }

  // 2. Loop through all named anchors
  for (name, pos) in trace-data.anchors {
    group({
      // A. Draw a visual "Crosshair" at the exact point
      let s = 0.25 // size of crosshair arms
      line(vector.add(pos, (-s, 0)), vector.add(pos, (s, 0)), stroke: 0.5pt + color)
      line(vector.add(pos, (0, -s)), vector.add(pos, (0, s)), stroke: 0.5pt + color)
      
      // B. Draw a circle to highlight the intersection
      circle(pos, radius: s/2, fill: none, stroke: 0.5pt + color)

      // C. Draw the Label Name
      // We apply the offset so the text doesn't obscure the geometry corner
      let text-pos = vector.add(pos, offset)
      content(
        text-pos, 
        text(fill: color, size: size, weight: "bold", font: "Barlow", name),
        anchor: "south-west" // Anchors text bottom-left to the offset point
      )
    })
  }
}


/// --- CALLOUT (LEADER LINE) FUNCTION ---
// target: The exact coordinate you are pointing at (e.g., a wall or machine)
// text-pos: Where the text and the "shoulder" line begin
// label: The text to display
// shoulder: The length of the flat landing line before it angles down to the target
#let callout(target, text-pos, label, shoulder: 2.0, stroke: 0.5pt, size: 8pt) = {
  let (tx, ty) = text-pos
  let (x, y) = target
  
  // 1. Calculate the direction of the shoulder
  // If the target is to the right of the text, the shoulder goes right (+1)
  // If the target is to the left, the shoulder goes left (-1)
  let dir = if x >= tx { 1 } else { -1 }
  let shoulder-pt = (tx + (shoulder * dir), ty)
  
  group({
    // 2. Draw the continuous leader line (Shoulder -> Angle -> Target)
    line(text-pos, shoulder-pt, target, mark: (end: ">", fill: black), stroke: stroke)
    
    // 3. Place the text resting perfectly on top of the shoulder line
    let text-anchor = if dir == 1 { "south-west" } else { "south-east" }
    
    // Nudge the text up slightly so it doesn't touch the ink of the line
    let nudge-y = 0.2 
    
    content(
      (tx, ty + nudge-y), 
      text(size: size, weight: "bold", label), 
      anchor: text-anchor
    )
  })
}


/// --- DRAFTING / DEBUG GRID ---
// Draws a light background grid and labels every intersection with its (X, Y) coordinate
#let drafting-grid(width, height, step: 5.0, stroke: 0.5pt + luma(220), text-size: 5pt) = {
  // CLAMP SAFETY: Force the text size to always stay between 2pt and 8pt
  let safe-text-size = calc.max(2pt, calc.min(text-size, 8pt))

  group({
    // 1. Draw the physical grid lines (CeTZ handles this natively and very fast)
    grid((0,0), (width, height), step: step, stroke: stroke)
    
    // 2. SAFETY CHECK: Skip text calculation if step < 1 to prevent compilation freeze
    if step >= 1.0 {
      let x-lines = int(calc.ceil(float(width) / float(step))) + 1
      let y-lines = int(calc.ceil(float(height) / float(step))) + 1

      for i in range(x-lines) {
        let current-x = i * step
        
        for j in range(y-lines) {
          let current-y = j * step
          
          if current-x <= width + 0.01 and current-y <= height + 0.01 {
            let lbl-x = str(calc.round(current-x, digits: 1))
            let lbl-y = str(calc.round(current-y, digits: 1))
            
            content(
              (current-x + 0.2, current-y + 0.2), 
              text(size: safe-text-size, fill: luma(150), lbl-x + ", " + lbl-y),
              anchor: "south-west"
            )
          }
        }
      }
    }
  })
}


/// --- EDGE RULERS ---
// Draws CAD-style rulers strictly on the Left and Top edges of the drawing area.
#let drafting-ruler(width, height, step: 5.0, stroke: 0.5pt + black, text-size: 5pt, tick: 0.5) = {
  // CLAMP SAFETY: Force the text size to always stay between 2pt and 8pt
  let safe-text-size = calc.max(2pt, calc.min(text-size, 8pt))

  group({
    // SAFETY CHECK: Skip calculation if step < 1
    if step >= 0.5 {
      let x-lines = int(calc.ceil(float(width) / float(step))) + 1
      let y-lines = int(calc.ceil(float(height) / float(step))) + 1

      // 1. LEFT RULER (Y-Axis)
      // Draws the main line from bottom to top
      line((0, 0), (0, height), stroke: stroke)
      
      for j in range(y-lines) {
        let current-y = j * step
        if current-y <= height + 0.01 {
          // Draw tick mark pointing outward (left)
          line((0, current-y), (-tick, current-y), stroke: stroke)
          
          // Place label next to the tick mark
          let lbl = str(calc.round(current-y, digits: 1))
          content(
            (-tick - 0.2, current-y), 
            text(size: safe-text-size, fill: luma(100), lbl),
            anchor: "east" // Aligns text to the right so it doesn't cross the line
          )
        }
      }

      // 2. TOP RULER (X-Axis)
      // Draws the main line from left to right at the very top of the canvas
      line((0, height), (width, height), stroke: stroke)
      
      for i in range(x-lines) {
        let current-x = i * step
        if current-x <= width + 0.01 {
          // Draw tick mark pointing outward (up)
          line((current-x, height), (current-x, height + tick), stroke: stroke)
          
          // Place label above the tick mark
          let lbl = str(calc.round(current-x, digits: 1))
          content(
            (current-x, height + tick + 0.2), 
            text(size: safe-text-size, fill: luma(100), lbl),
            anchor: "south" // Aligns text to the bottom
          )
        }
      }
    }
  })
}



#let bricks-fill = tiling(size: (40pt, 20pt))[
  #let stroke-style = 0.6pt // Dark navy like your image
  
  // 1. Horizontal Lines (Top and Middle)
  #std.place(std.line(start: (0pt, 0pt), end: (40pt, 0pt), stroke: stroke-style))
  #std.place(std.line(start: (0pt, 10pt), end: (40pt, 10pt), stroke: stroke-style))
  
  // 2. Vertical Lines - Row 1 (at x = 0)
  #std.place(std.line(start: (0pt, 0pt), end: (0pt, 10pt), stroke: stroke-style))
  
  // 3. Vertical Lines - Row 2 (at x = 20pt, shifted by half)
  #std.place(std.line(start: (20pt, 10pt), end: (20pt, 20pt), stroke: stroke-style))
]

// --- HATCH TILING ---
#let hatch-fill = tiling(size: (10pt, 10pt))[
  #std.line(start: (0pt, 0pt), end: (10pt, 10pt), stroke: 0.5pt + black)
]


// --- GRASS TILING ---
#let grass-fill = tiling(size: (5pt, 8pt))[
  #std.rotate(270deg)[
  #text(fill: green)[#sym.prec]]
]
