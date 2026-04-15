/// Internal math helper to find the intersection of two vector lines.
#let intersect-lines(p1, v1, p2, v2) = {
  let det = v1.at(0) * v2.at(1) - v1.at(1) * v2.at(0)
  if calc.abs(det) < 0.0001 { return p1 } // Parallel safety
  
  let dx = p2.at(0) - p1.at(0)
  let dy = p2.at(1) - p1.at(1)
  let t = (dx * v2.at(1) - dy * v2.at(0)) / det
  
  (p1.at(0) + t * v1.at(0), p1.at(1) + t * v1.at(1))
}


/// Detects if a point sits perfectly flush on a line segment
#let point-on-segment(pt, p1, p2) = {
  let (px, py) = pt
  let (x1, y1) = p1; let (x2, y2) = p2
  let d1 = calc.sqrt(calc.pow(px - x1, 2) + calc.pow(py - y1, 2))
  let d2 = calc.sqrt(calc.pow(px - x2, 2) + calc.pow(py - y2, 2))
  let d3 = calc.sqrt(calc.pow(x1 - x2, 2) + calc.pow(y1 - y2, 2))
  if calc.abs((d1 + d2) - d3) < 0.005 { return true }
  return false
}


/// 1. Parametric Line Segment Intersection
#let intersect-segments(p1, p2, p3, p4) = {
  let (x1, y1) = p1; let (x2, y2) = p2
  let (x3, y3) = p3; let (x4, y4) = p4
  let den = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
  if den == 0 { return none } // Parallel
  
  let t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / den
  let u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / den
  
  // Only return if they intersect within the segment bounds!
// THE FIX: Allow intersections exactly at the tips of the lines (-0.005 to 1.005)
  if t >= -0.005 and t <= 1.005 and u >= -0.005 and u <= 1.005 {
    return (x1 + t * (x2 - x1), y1 + t * (y2 - y1))
  }
  return none
}

/// Calculates the exact intersection points between a line segment and a circle.
/// Returns an array of coordinates (empty if they miss, 1 or 2 if they cross).
#let intersect-line-circle(p1, p2, center, radius) = {
  let (x1, y1) = p1
  let (x2, y2) = p2
  let (cx, cy) = center

  // 1. Setup the parametric variables
  let dx = x2 - x1
  let dy = y2 - y1
  let fx = x1 - cx
  let fy = y1 - cy

  // 2. Build the Quadratic Equation (A, B, C)
  let a = (dx * dx) + (dy * dy)
  let b = 2 * ((fx * dx) + (fy * dy))
  let c = (fx * fx) + (fy * fy) - (radius * radius)

  // 3. Calculate the Discriminant
  let discriminant = (b * b) - (4 * a * c)

  // If discriminant is negative, the line missed the circle entirely!
  if discriminant < 0 {
    return () 
  }

  let intersections = ()
  let sqrt-disc = calc.sqrt(discriminant)

  // 4. Calculate the two possible intersection points (t1 and t2)
  let t1 = (-b - sqrt-disc) / (2 * a)
  let t2 = (-b + sqrt-disc) / (2 * a)

  // 5. Check if the first hit actually happened ON our wall segment (0.0 to 1.0)
  if t1 >= 0.0 and t1 <= 1.0 {
    intersections.push((x1 + t1 * dx, y1 + t1 * dy))
  }

  // 6. Check if the second hit happened on our wall segment
  if discriminant > 0 and t2 >= 0.0 and t2 <= 1.0 {
    intersections.push((x1 + t2 * dx, y1 + t2 * dy))
  }

  return intersections
}


/// 2. THE ANGLE FILTER: Filters hits to only allow those on the physical arc
#let intersect-line-arc(p1, p2, center, radius, start-angle, sweep) = {
  // Get all hits on the full 360-degree circle
  let circle-hits = intersect-line-circle(p1, p2, center, radius)
  let valid-hits = ()

  // Math Helper: Keeps angles strictly between 0 and 360 degrees
  let norm(a) = {
    let d = calc.rem(a, 360.0)
    if d < 0.0 { d + 360.0 } else { d }
  }

  let s = norm(start-angle.deg())
  let e = norm((start-angle + sweep).deg())
  let is-cw = sweep < 0deg // Check if turning clockwise

  for hit in circle-hits {
    // Calculate the angle of this specific hit from the center
    let hx = hit.at(0) - center.at(0)
    let hy = hit.at(1) - center.at(1)
    let hit-angle = calc.atan2(hx, hy)
    let target = norm(hit-angle.deg())

    // Filter: Is the target angle inside the swept arc?
    let inside = false
    if not is-cw { 
      if s <= e { inside = (target >= s and target <= e) }
      else { inside = (target >= s or target <= e) }
    } else {       
      if e <= s { inside = (target >= e and target <= s) }
      else { inside = (target >= e or target <= s) }
    }

    if inside { valid-hits.push(hit) }
  }
  return valid-hits
}

/// 1.5 Point on Segment Detector (Catches T-Junctions)
#let point-on-segment(pt, p1, p2) = {
  let (px, py) = pt
  let (x1, y1) = p1; let (x2, y2) = p2
  let d1 = calc.sqrt(calc.pow(px - x1, 2) + calc.pow(py - y1, 2))
  let d2 = calc.sqrt(calc.pow(px - x2, 2) + calc.pow(py - y2, 2))
  let d3 = calc.sqrt(calc.pow(x1 - x2, 2) + calc.pow(y1 - y2, 2))
  if calc.abs((d1 + d2) - d3) < 0.005 { return true }
  return false
}

/// 2. Local Coordinate Transformer (With Auto-Melt)
#let get-wall-corners(w, default-t) = {
  let t = w.at("thickness", default: default-t)
  let a = w.at("align", default: "center")
  let (x1, y1) = w.from; let (x2, y2) = w.to
  
  // THE FIX: Automatically apply a microscopic 0.05 overlap to force joins!
  let ext-s = w.at("ext-start", default: 0)
  let ext-e = w.at("ext-end", default: 0)

  let dx = x2 - x1; let dy = y2 - y1
  let len = calc.sqrt(dx*dx + dy*dy)
  if len == 0 { return () }
  let nx = dx / len; let ny = dy / len
  
  let ex1 = x1 - nx * ext-s
  let ey1 = y1 - ny * ext-s
  let ex2 = x2 + nx * ext-e
  let ey2 = y2 + ny * ext-e
  
  let t-left = if a == "left" { t } else if a == "right" { 0 } else { t / 2 }
  let t-right = if a == "left" { 0 } else if a == "right" { t } else { t / 2 }
  
  let c1 = (ex1 - ny*t-left, ey1 + nx*t-left)
  let c2 = (ex2 - ny*t-left, ey2 + nx*t-left)
  let c3 = (ex2 + ny*t-right, ey2 - nx*t-right)
  let c4 = (ex1 + ny*t-right, ey1 - nx*t-right)
  
  // Return the new coordinates
  return (c1, c2, c3, c4, len + ext-s + ext-e, nx, ny, t-left, t-right, ex1, ey1)
}

/// 3. The "Inside Wall" Detector (Updated for Auto-Melt)
#let is-inside-any-wall(pt, walls, default-t) = {
  let eps = 0.005 
  for w in walls {
    if w.at("style", default: "wall") == "line" { continue }
    let data = get-wall-corners(w, default-t)
    if data.len() == 0 { continue }
    
    // Catch the new variables
    let (c1, c2, c3, c4, ext-len, nx, ny, t-left, t-right, ex1, ey1) = data
    
    // Shift using the extended starting point
    let vx = pt.at(0) - ex1
    let vy = pt.at(1) - ey1
    let local-x = vx * nx + vy * ny
    let local-y = -vx * ny + vy * nx 
    
    if local-x > eps and local-x < (ext-len - eps) and local-y > (-t-right + eps) and local-y < (t-left - eps) {
      return true
    }
  }
  return false
}



/// --- HELPER FUNCTIONS ---

/// Internal helper: Calculate angle manually using standard Typst math
/// 
/// - v (array): The vector.
#let get-angle(v) = {
  // calc.atan2(x, y) returns the angle of the vector relative to X-axis
  calc.atan2(v.at(0), v.at(1))
}

/// Internal helper: Calculates the perpendicular shift based on alignment
/// 
/// - align (string): "left", "right", or "center"
/// - thickness (float): Wall thickness
#let get-align-dy(align, thickness) = {
  if align == "left" { thickness / 2 } 
  else if align == "right" { -thickness / 2 } 
  else { 0 }
}

/// Internal math helper to offset a polygon inward by given widths.
#let inset-polygon(pts, widths) = {
  let n = pts.len()
  let new-pts = ()
  let lines = ()
  
  for i in range(n) {
    let p-curr = pts.at(i)
    let p-next = pts.at(calc.rem(i + 1, n))
    let w = widths.at(calc.rem(i, widths.len())) 
    
    let dx = p-next.at(0) - p-curr.at(0)
    let dy = p-next.at(1) - p-curr.at(1)
    let dist = calc.sqrt(dx*dx + dy*dy)
    
    let nx = -dy / dist
    let ny = dx / dist
    
    lines.push((
      start: (p-curr.at(0) + nx*w, p-curr.at(1) + ny*w),
      dir: (dx, dy)
    ))
  }
  
  for i in range(n) {
    let l1 = lines.at(calc.rem(i - 1 + n, n))
    let l2 = lines.at(i)
    new-pts.push(intersect-lines(l1.start, l1.dir, l2.start, l2.dir))
  }
  return new-pts
}


/// Helper to extract an array of plain coordinates from a list of wall dictionaries.
/// 
/// - wall-list (array): Sliced array of walls.
#let get-pts(wall-list) = {
  if wall-list.len() == 0 { return () }
  let pts = (wall-list.first().from,)
  for w in wall-list {
    pts.push(w.to)
  }
  return pts
}


/// Calculates the exact (x,y) and tangent angle along an arc
/// - fraction: 0.0 is the start point, 0.5 is the exact middle, 1.0 is the end.
#let get-arc-transform(p1, p2, radius, fraction: 0.5, ccw: true, large: false) = {
  let dx = p2.at(0) - p1.at(0)
  let dy = p2.at(1) - p1.at(1)
  let d = calc.sqrt(dx * dx + dy * dy)
  if d == 0 { return (pos: p1, angle: 0deg) } 

  let actual-r = if radius < d / 2.0 { d / 2.0 } else { radius }
  let mx = (p1.at(0) + p2.at(0)) / 2.0
  let my = (p1.at(1) + p2.at(1)) / 2.0
  let h = calc.sqrt(actual-r * actual-r - (d / 2.0) * (d / 2.0))

  let nx = -dy / d
  let ny = dx / d
  let sign = if ccw == large { -1.0 } else { 1.0 }
  let cx = mx + sign * h * nx
  let cy = my + sign * h * ny

  let start-ang = calc.atan2(p1.at(0) - cx, p1.at(1) - cy)
  let end-ang = calc.atan2(p2.at(0) - cx, p2.at(1) - cy)

  let sweep = end-ang - start-ang
  if ccw and sweep < 0deg { sweep += 360deg }
  if not ccw and sweep > 0deg { sweep -= 360deg }

  // Find the requested point on the arc
  let target-ang = start-ang + (sweep * fraction)
  let px = cx + actual-r * calc.cos(target-ang)
  let py = cy + actual-r * calc.sin(target-ang)
  
  // Tangent angle is exactly 90 degrees offset from the radius
  let tangent = target-ang + 90deg

  (pos: (px, py), angle: tangent)
}


/// Calculates the physical length of a curved wall
/// Uses the exact same parameters as draw-arc-to
#let get-arc-length(p1, p2, radius, ccw: true, large: false) = {
  let dx = p2.at(0) - p1.at(0)
  let dy = p2.at(1) - p1.at(1)
  let d = calc.sqrt(dx * dx + dy * dy)
  
  if d == 0 { return 0.0 } // Safety check

  let actual-r = if radius < d / 2.0 { d / 2.0 } else { radius }
  let mx = (p1.at(0) + p2.at(0)) / 2.0
  let my = (p1.at(1) + p2.at(1)) / 2.0
  let h = calc.sqrt(actual-r * actual-r - (d / 2.0) * (d / 2.0))

  let nx = -dy / d
  let ny = dx / d
  let sign = if ccw == large { -1.0 } else { 1.0 }
  let cx = mx + sign * h * nx
  let cy = my + sign * h * ny

  let start-ang = calc.atan2(p1.at(0) - cx, p1.at(1) - cy)
  let end-ang = calc.atan2(p2.at(0) - cx, p2.at(1) - cy)

  let sweep = end-ang - start-ang
  if ccw and sweep < 0deg { sweep += 360deg }
  if not ccw and sweep > 0deg { sweep -= 360deg }

  // Convert the sweep angle to raw radians and multiply by radius
  let sweep-rad = calc.abs(sweep / 180deg * calc.pi)
  
  return actual-r * sweep-rad
}
