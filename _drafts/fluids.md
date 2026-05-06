---
layout: post
title: Fluid simulation explained with Godot game engine
published: false
---

## Introduction

TODO: fluid_sim_11 vid?

When I first stumbled upon fluid simulations in game dev I was amazed on how good the effect could be. I really wanted to learn how this works, but learning materials on this topic are suprisingly sparse - and those which I found were pretty difficult to understand. Nonetheless, I decided to give it a try; and - while I'm at it - why not create a blog post out of it to hopefully make it easier for the next guy?

Before we begin, I want to stress a few points:
* I'm not a mathematician. If you find errors in my explanations, please DM me on Bluesky or send an email and I'll correct it
* This implementation is for learning purposes only. For that reason it is implemented in a way that is not the best performance-wise. Calculations are made solely on the CPU. We introduce way too many variables. All of that to make it easier to read and learn, not necessarily to squeeze the most FPS.

Learning materials I used:
* "Real-Time Fluid Dynamic for Games" by Jos Stam (PDF)
* ["Fluid Simulation for Dummies" by Mike Ash](https://www.mikeash.com/pyblog/fluid-simulation-for-dummies.html)

You can find all of the code in this repository: [github.com/rskupnik/godot-fluid-simulation-demo](https://github.com/rskupnik/godot-fluid-simulation-demo)

I used git commits to mark code checkpoints matching the chapters of this blog post, so if you don't want to write the code alongside you can make use of the [commit view](https://github.com/rskupnik/godot-fluid-simulation-demo/commits/master/) to follow along. For your convenience, I include a "project snapshot" and a "diff" link at each chapter, which lead to, respectively: the codebase at this point and the commit diff view

TODO: Image here

---
## AI Disclosure

Every word of this blog post and every line of this codebase is written by me.

AI was only used for research.

---
## Foundations

The algorithms we will use are based on physical equations for fluid flow - the Navier Stokes equations. Our use case is a game dev one - so we want to sacrifice precision of these calculations in favour of speed. The effect needs to be good enough but not overly expensive. We achieve this in three ways. First of all, we use a relatively small grid with large cells. Second - we advance the simulation in arbitrary time steps. Finally, we use approximation equations (such as Gauss-Seidel relaxation) to arrive at good-enough solutions to some equations.

Let me start with the mathematical description of what we will do in this blog post. This description might sound daunting, but don't worry - we'll explain everything as we go. Here goes: we will simulate fluid flow by moving a scalar density field through a vector velocity field. We'll simulate velocity diffusion and advection as well as density diffusion and advection. Then we will add velocity projection with the goal of making the fluid obey the lay of mass conservation - which will happen by balancing divergence with a pressure field. We will use bilinear interpolation and Gauss-Seidel relaxation for approximating values where needed.

Alright, with all of that out of the way, let's begin!

---
## The journey begins with a grid

[Project snapshot](https://github.com/rskupnik/godot-fluid-simulation-demo/tree/0a755f8eb80a56cb990f68b95356f38445770bb3)

Create a new Godot project and add a Node2D. I called mine "FluidGrid". Attach a script to it. All the code goes into that script.

First, let's define the grid:

```
@export var N := 16
@export var cell_size := 32

var size := 0
```

Here, `N` is the amount of cell in a row and column - basically the size of the grid - and `cell_size` is the size of a single cell in pixels. We also define `size`, which we will soon initialize.

Next, let's add arrays for storing the actual data.

```
# Density means "how much material does this cell contain"
var density: PackedFloat32Array
var density_prev: PackedFloat32Array

# "u" stores the horizontal velocity (x direction)
var u: PackedFloat32Array
var u_prev: PackedFloat32Array

# "v" stores the vertical velocity (y direction)
var v: PackedFloat32Array
var v_prev: PackedFloat32Array
```

For now, we need three arrays - `density` will store the density, `u` will store horizontal velocity and `v` - vertical velocity.

Density tells us how much material does a given cell contain - it will range between `0.0` and `1.0`, where 0 is empty and 1 is full. Technically, it can go above 1.0 but we will only display up to 1.0. The way we display density is simple - with color. A cell full of density will be fully white and without density - fully transparent.

The velocity arrays also store floats and they describe velocity at a given cell. A velocity of 0 means no movement, then it can go positive or negative which corressponds to going right or left (for horizontal) and down or up (for vertical). Combined, they tell us the velocity at a given cell. We could just store the velocities as a single array of `Vector2f`, but it will be much easier for calculations if we separate them as two float arrays. When it comes to displaying this information - we will draw small blue arrows for each cell.

You might also wonder why each array has a `_prev` equivalent - that's because for some of the calculations we will iterate over the real arrays and modify the data live - and in those cases we need to "snapshot" the data before we start iterating, so we can see what the values were before we started modifying them. That will be mostly used in the approximating equations. I follow the naming convention of Stam's paper with this `_prev` name, although I believe `_snapshot` would be a more descriptive name.

Alright, let's move on. Time to initialize all of these!

```
func _ready():
	# Resize all the arrays properly
	# We use a single-dimensional array to store the grid, which is why we need to multiply N
	# The "+2" is added for borders, because there are two for each dimension (x, and y)
	# For x dimension, there's a single cell border on the left and on the right, hence "+2". Same for the y direction
	size = (N + 2) * (N + 2)

	density.resize(size)
	density_prev.resize(size)
	u.resize(size)
	v.resize(size)
	u_prev.resize(size)
	v_prev.resize(size)

	queue_redraw()
```

TODO: Image of the grid here

We could use a two-dimensional array, but it will be simpler to work with a single-dimensional one. We just need one helper function to make it easier to index this array.

```
# This is a helper function that makes it easier to work with a grid when it is
# packed into a single-dimension array
# We can call it with the cell index (i and j) and it will translate it into
# an index in the single-dimension array
func IX(i: int, j: int) -> int:
	return i + (N + 2) * j
```

With all of that, we can now implement the `_draw()` function to display the grid.

```
# This is the standard Godot function used for drawing
# We want to draw a simple grid of (N+2)*(N+2) rectangles of size cell_size
func _draw():
	for j in range(0, N + 2):
		for i in range(0, N + 2):
			var x := i * cell_size	# this translates the index into pixel position on screen
			var y := j * cell_size
			var rect := Rect2(x, y, cell_size, cell_size)

			var is_boundary := i == 0 or j == 0 or i == N + 1 or j == N + 1
			var fill := Color(0.16, 0.08, 0.08) if is_boundary else Color(0.08, 0.08, 0.08)

			draw_rect(rect, fill, true)
			draw_rect(rect, Color(0.35, 0.35, 0.35), false)
```

It's pretty self-explanatory. We iterate over the grid and draw each cell as a simple `Rect2`, changing the color slightly for the border cells.

You can now run the project and you should see this:

TODO: Image of the grid

---
## Putting "fluid" in "fluid simulation"

[Project snapshot](https://github.com/rskupnik/godot-fluid-simulation-demo/tree/12e1eaa8f03e3b8addba5c688478de65f717e9de)

[Diff](https://github.com/rskupnik/godot-fluid-simulation-demo/commit/12e1eaa8f03e3b8addba5c688478de65f717e9de)

Now that we have a grid, let's add some fluid to it.

We will start very simple - we'll make it possible to add density to a cell by clicking it with a mouse. Then we will make the density slowly fade away - this will be useful later so we can experiment without making the grid fill with fluid and requiring a restart.

```
# This helper function translates the position we clicked on with the mouse
# into the cell coordinates
# So if we click somewhere in the grid, it will return a Vector2i, where the
# first element is the index of the cell in that grid in x dimension
# and the other element is the index of the cell in the y dimension
func cell_from_mouse(pos: Vector2) -> Vector2i:
	return Vector2i(floor(pos.x / cell_size), floor(pos.y / cell_size))

# This is the standard Godot function for processing input
# We want to detect a mouse click and inject density into the clicked cell
# Density is represented as a float number and is stored in the "density" array
func _input(event):
	if event is InputEventMouseButton and event.pressed:
		# figure out the cell that was clicked
		var cell := cell_from_mouse(to_local(event.position))
		var i := cell.x
		var j := cell.y

		if i >= 1 and i <= N and j >= 1 and j <= N:
			density[IX(i, j)] += 1.0	# inject density into the cell
			queue_redraw()				# tell Godot to redraw the grid
```

And now we need to draw what's inside the density array. Go to the `_draw` function and change the `var fill := Color...` line to this (see the diff linked above if confused).

```
var fill := Color(0.08, 0.08, 0.08)
if is_boundary:
    fill = Color(0.16, 0.08, 0.08)
else:
    # Even though density can go above 1.0, we need to clamp it to values between 0.0 and 1.0 for drawing
    var d : float = clamp(density[IX(i, j)], 0.0, 1.0)
    fill = Color(d, d, d)
```

We make use of the `IX()` function to index the density array and use that to determine the "intensity" of the colour in a cell. For now, each click of a mouse injects `1.0` density into a cell, so that cell should turn white.

This is the effect

TODO: fluid_sim_1 vid

---
## Fade away, fade away, fade away

[Project snapshot](https://github.com/rskupnik/godot-fluid-simulation-demo/tree/3fef7f109084e026b0111aea47e83715c54302ba)

[Diff](https://github.com/rskupnik/godot-fluid-simulation-demo/commit/3fef7f109084e026b0111aea47e83715c54302ba)

As mentioned, we want to add a simple fading effect so the density slowly disappears - to avoid clogging our grid later on.

Let's begin with a simple variable controlling the intensity of this effect:

```
@export var density_fade_rate := 0.1
```

Now, time for the `fade_density()` function

```
# Fade density as the time passes
func fade_density(delta: float) -> void:
	for j in range(1, N + 1):
		for i in range(1, N + 1):
			var idx := IX(i, j)
			# We need to multiply the rate of density fade through delta
			# to make it the same despite the framerate
			density[idx] = max(0.0, density[idx] - density_fade_rate * delta)
```

In this function, we go over each cell and decrease the amount of density in that cell by the amount denoted by the rate of density fading multiplied with the time delta. If you come from the gamedev world, you are probably familiar with `delta`, but just for the sake of completion - this variable is provided by the Godot engine itself and it contains the amount of time that has passed since the last frame was drawn. It is meant to be used in various equations to either simulate the passage of time or bind some effect to the user's framerate.

Finally, we need to call this `fade_density()` function every frame, which we will do using Godot's standard `_process()` function

```
# This is the standard Godot function called every frame
# It's the heart of our simulation
# The "delta" variable holds the amount of time that passed since the last frame
# For now we use it to slowly fade the density
func _process(delta: float) -> void:
	fade_density(delta)
	queue_redraw()
```

Since we now modify the density array every frame (by fading it away), we also need to redraw the grid every frame, which is what `queue_redraw()` is for. Again - it's a Godot built-in function.

At this point, you should be able to click the cells to add density and see how it slowly fades away

TODO: fluid_sim_2 vid

---
## Time for some arrows

[Project snapshot](https://github.com/rskupnik/godot-fluid-simulation-demo/tree/ac5b28b58f084a8a39b5751f033cb052f36f8209)

[Diff](https://github.com/rskupnik/godot-fluid-simulation-demo/commit/ac5b28b58f084a8a39b5751f033cb052f36f8209)

Alright, now that we can see the density, it's time to also visualize velocity.

Start with a variable for controlling the scale of the arrows

```
@export var velocity_draw_scale := 20.0
```

This can be used to make the arrows prettier. It doesn't affect the velocity itself, it only affects the scaling factor of the arrows we draw. Want bigger arrows? Increase the param. Arrows are way too big? Scale them down! Again, it's important to note that this param does not affect the simulation in any way - it's purely visual.

Our velocity field is currently initialized to `0.0` in every cell - so let's hardcode some temporary velocities to make sure the drawing works properly. You should remove those at the end of this step.

Add those in `_ready()`

```
# TEMPORARY
# In this cell, we set the horizontal velocity to 1.0 and vertical to 0.0
# Result: horizontal arrow pointing right
u[IX(8, 8)] = 1.0
v[IX(8, 8)] = 0.0

# In this cell, we set the horizontal velocity to 0.0 and vertical to -1.0
# Result: vertical arrow pointing up
# Remember that in Godot, the y axis goes from top to bottom, hence why -1.0 points up
u[IX(9, 8)] = 0.0
v[IX(9, 8)] = -1.0

# In this cell, we set the horizontal velocity to 1.0 and vertical to -1.0
# Result: vertical arrow pointing up and right (diagonal)
# Remember that in Godot, the y axis goes from top to bottom, hence why -1.0 points up
u[IX(10, 8)] = 1.0
v[IX(10, 8)] = -1.0
```

Ok, now we need a function to draw the arrows. Before we do that - rename the current `_draw()` function to `_draw_grid()`. Then add the `_draw_velocity_arrows()` below.

```
# Draw velocity arrows in inner cells with tiny circles as arrow tips
func _draw_velocity_arrows():
	for j in range(0, N + 2):
		for i in range(0, N + 2):
			var is_boundary := i == 0 or j == 0 or i == N + 1 or j == N + 1
			if not is_boundary:
				var idx := IX(i, j)
				var center := Vector2(
					i * cell_size + cell_size * 0.5,
					j * cell_size + cell_size * 0.5
				)

				var velocity := Vector2(u[idx], v[idx])
				var end := center + velocity * velocity_draw_scale

				draw_line(center, end, Color(0.2, 0.8, 1.0), 2.0)
				draw_circle(end, 2.5, Color(0.2, 0.8, 1.0))
```

In this function, we define a `Vector2` which consists of the horizontal velocity in this cell (the `u` array) and the vertical velocity in this cell (the `v` array). We then define a `center` variable, which denotes the center of the cell and also the starting point of our velocity arrow; and an `end` variable which utilizes our `velocity_draw_scale` param. Then we pass both `center` and `end` to `draw_line` (which is a Godot function), which tells Godot to draw a line starting at `center` and ending at `end`. Since we scale the `end` with `velocity_draw_scale`, the arrow gets proportionally longer or shorter depending on how big we set `velocity_draw_scale`. Finally, we draw a tiny circle at the end to act as a sort of "arrow point".

Alright, but we still need to call this function. Let's restore `_draw()`, defined like this

```
func _draw():
	_draw_grid()
	_draw_velocity_arrows()
```

So now Godot's standard `_draw()` function will draw both the grid itself (with density) and velocity arrows

Since we hardcoded a few velocities, you should now see this:

TODO: Image of hardcoded velocities

---
# Let's get this moving

Alright, we are almost over with the mundane stuff - I promise! Let's just quickly revise our `_input()` so that we can inject both density and velocity by dragging the mouse.