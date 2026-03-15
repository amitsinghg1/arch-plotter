# Arch-Plotter

**Arch-Plotter** is a powerful, parametric 2D CAD and land surveying engine built for [Typst](https://typst.app/) and powered by [CeTZ](https://github.com/cetz-package/cetz). 

Whether you are drafting interior floor plans with dynamic walls and furniture, or generating legally accurate surveying documents with automatic area calculations and peg schedules, Arch-Plotter handles the complex geometry so you can focus on drafting.

## Features
* **Two Distinct Engines:** A dedicated toolset for Architecture (buildings/interiors) and Plotting (land surveying/subdivisions).
* **Parametric Drafting:** Draw using standard CAD commands (`R`, `L`, `U`, `D`, `Mark`, `Jump`) without needing to calculate raw coordinates.
* **Auto-Documentation:** Instantly generate Perimeter/Area schedules and X/Y Corner Coordinate tables directly from your drawings.
* **Layer System:** Draw structural boundaries, dashed setbacks, and utility easements in a single pass.
* **Smart Components:** Drop in scalable, rotatable parametric furniture (beds, gas burners, washbasins, etc.).

---

## 🚀 Quick Start

To avoid namespace collisions between the interior drafting tools and the land surveying tools, **Arch-Plotter uses scoped imports.** Instead of importing everything globally, import the canvas wrapper from the main package, and then import the specific engine you need directly. This allows you to use shorthand commands like `R(10)` without typing prefixes!

### Example 1: Interior Architecture (`Arch.typ`)
Draft a floor plan and drop in some furniture.

```typst
#import "@preview/cetz:0.4.2"
#import "@preview/arch-plotter:0.1.0": arch-canvas
// Import Arch tools directly to use shorthand commands
#import "@preview/arch-plotter:0.1.0/Arch.typ": *

#arch-canvas(scale: 0.5cm, {
  import cetz.draw: *
  
  // 1. Trace the structural walls
  let house = trace(start: (0,0), (
    R(50), U(40), L(50), C()
  ))
  draw-walls(house)
  
  // 2. Add interior components
  bed((15, 20), size: "queen", rotation: 90deg)
  gas-burner((5, 35), scale: 1.2)
})