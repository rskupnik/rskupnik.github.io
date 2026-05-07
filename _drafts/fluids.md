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
# Let's get this moving!

[Project snapshot](https://github.com/rskupnik/godot-fluid-simulation-demo/tree/55fd89dfbb76cf590dead009b5e9e22d582f6eb3)

[Diff](https://github.com/rskupnik/godot-fluid-simulation-demo/commit/55fd89dfbb76cf590dead009b5e9e22d582f6eb3)

Alright, before moving further let's just quickly revise our `_input()` so that we can inject both density and velocity by dragging the mouse.

First, some variables

```
@export var velocity_add_scale := 0.06

var is_dragging := false
var last_mouse_cell := Vector2i.ZERO
```

The `velocity_add_scale` will control how much velocity we add with a single mouse stroke. The rest are operational variables for tracking the mouse.

Now replace the entire `_input()` function with this

```
# This is the standard Godot function for processing input
# We want to detect when a mouse is dragged while clicked and the inject
# both density and velocity at the relevant cells
func _input(event):
	if event is InputEventMouseButton:
		is_dragging = event.pressed
		last_mouse_cell = cell_from_mouse(to_local(event.position))

	if event is InputEventMouseMotion and is_dragging:
		var local_pos := to_local(event.position)
		var cell := cell_from_mouse(local_pos)

		var i := cell.x
		var j := cell.y

		if i >= 1 and i <= N and j >= 1 and j <= N:
			# event.relative stores the relative difference between last time
			# this function was called and this time
			# in this case, it tells us how far the mouse has travelled
			# we use that to decide how much velocity to add
			var delta_velocity : Vector2 = event.relative * velocity_add_scale
			var idx := IX(i, j)

			# Inject the velocity into the cell
			# u stores horizontal velocity, v stores vertical velocity
			u[idx] += delta_velocity.x
			v[idx] += delta_velocity.y

			# Inject density
			density[idx] += 1.0

			queue_redraw()
```

If you run the project now, you can drag the mouse while holding left click to add both velocity and density. If you want to add density in a single place just keep the left mouse button clicked and do small drag movements in that cell.

TODO: fluid_sim_3 vid

---
## Hold your horses

[Project snapshot](https://github.com/rskupnik/godot-fluid-simulation-demo/tree/eeeaccabfecd162ad13c1b175db6ee3d4b0ad928)

[Diff](https://github.com/rskupnik/godot-fluid-simulation-demo/commit/eeeaccabfecd162ad13c1b175db6ee3d4b0ad928)

As a final step before me move to the Serious Stuff, let's make velocity also slowly fade away. We will remove this effect at the end of this project, but for now it will come in handy.

First, as usual - a variable controlling the strength of this effect

```
@export var velocity_fade_rate := 0.2
```

Now a function that handles velocity fading

```
# Fade velocity as the time passes
func fade_velocity(delta: float) -> void:
	for j in range(1, N + 1):
		for i in range(1, N + 1):
			var idx := IX(i, j)
			# We need to multiply the rate of velocity fade through delta
			# to make it the same despite the framerate
			u[idx] = move_toward(u[idx], 0.0, velocity_fade_rate * delta)
			v[idx] = move_toward(v[idx], 0.0, velocity_fade_rate * delta)
```

This is almost identical to how we fade density. The only real difference is we are using Godot's `move_toward` function which smoothly interpolates the movement - just so it looks nice and smooth.

Finally, let's make sure this function gets called from within `_process()`

```
func _process(delta: float) -> void:
	fade_density(delta)
	fade_velocity(delta)
	queue_redraw()
```

With this, the velocity arrows should now slowly fade back to nothing

TODO: fluid_sim_4 vid

---
## Time to get serious - density advection

[Project snapshot](https://github.com/rskupnik/godot-fluid-simulation-demo/tree/bdca2f5280606bcbb504a91a101ddc74a45b74c1)

[Diff](https://github.com/rskupnik/godot-fluid-simulation-demo/commit/bdca2f5280606bcbb504a91a101ddc74a45b74c1)

Alright, all the things we did so far were pretty basic. This chapter is where we start working on the mechanics that make the magic happen.

We start with density advection. You already know that density is basically our fluid - it's a grid of floating point numbers that tells us how much material is currently present in a given cell. Advection is all about making that density move through our velocity field.

We have an array of density values and want to move them along the velocity vectors. How would you implement it? If you're like me, your first instinct might be to do some variation of "iterate over the grid, grab the density at a given cell, then grab the velocity at that cell and make the density move to wherever the velocity arrow points to". Apparently - this would be the hard way to approach this. I'll be honest with you - I don't fully understand why this would be difficult to calculate, but if people smarter than me claim so - I believe them.

According to Stam's paper, a better approach is to **track density backwards in time**. It works like this - first, we snapshot the density array. Then, for each cell, we ask the question - where did the density value currently in this cell come from? To answer that question, we could look at the velocity arrow in that cell. Ok cool, but that only tells us where the density **should go**, not **where it came from**. To figure that out, we can simply reverse that velocity arrow and see where we land. Then we can interpolate the values between the four surrounding neighbours of that point to figure out how much density should we take from there.

Now, there might be a red lamp blinking in your head right now. Just because the velocity at the currently inspected cell points, for example, to the right - doesn't mean that the density that came to this cell came from the left. It might have come from the top neighbour. Or the bottom one. I also asked myself the same question when first studying this algorithm - and apparently the answer is twofold. First of all - we are dealing with a velocity **field**. In such a field, it is very unlikely that the velocities would make a sudden turn like that. A situation where you have a velocity pointing straight down and then suddenly straight to the right is unlikely. This is a velocity field - they change gradually. Second of all - this is one of the places where we surrender perfect precision for good enough approximation.

These two arguments combined are why this solution makes much more sense - at least in my head :)

So what we are going to do is this (for each cell):
- Find the velocity, reverse it, multiply by the time delta - that will give us an approximation of where the density probably came from
- We will end up with a point that lays somewhere in the grid, **not necessarily in the center of a cell**. Let's call that the "source cell"
- We will find all the neighbours of that source cell
- We will figure out how close the source point is to each fo the neighbours. Remember - we don't necessary land on a cell center. The source point might be closer to the left and top (for example)
- With the source position, the source neighbouring tiles and the information of how close to each of the neighbours we are, we will use bilinear interpolation to figure out how much density we should take from each of those neighbours. The closer the point is to a neighbour - the more density should be taken from that neighbour (and less from the opposing neighbour)

Alright, let's implement this. I will provide the rest of explanations as code comments to not break the continuity of the function

```
func advect_density(delta: float) -> void:
	# Multiply delta by N to scale the time by grid size
	var dt0 := delta * N

	for j in range(1, N + 1):
		for i in range(1, N + 1):
			var idx := IX(i, j)

			# Notice this tracks backwards through time
			# First we subtract the velocity in this cell (multiplied by delta)
			# from the cell index
			# That tells us where the density in this cell came from (probably)
			# Then we clamp to make sure we don't go outside the grid
			# The result will be a position of where the density probably came from, lying somewhere
			# between other grid cells (not necessarily in a cell center)
			# For the sake of this example, let's assume we land at a point (7.3, 4.8)
			# Which means it's the lower-left corner of the cell (7,4)
			# (The center would be at (7.5, 4.5) )
			# Remember - in Godot, the y axis points down
			var x := i - dt0 * u[idx]
			var y := j - dt0 * v[idx]
			x = clamp(x, 0.5, N + 0.5)
			y = clamp(y, 0.5, N + 0.5)

			# This grabs the four cells surrounding the point we just calculated above
			# Assuming we land at (7.3, 4.8)
			# The four cells around this point (including the one it is part of)
			# will be: (7,4) (8,4) (7,5) (8,5), because
			# i0 = 7
			# i1 = 8
			# j0 = 4
			# j1 = 5
			# (it's a combination of all "i" with all "j")
			var i0 := int(floor(x))		# floor will cut off the decimal part, rounding down, so 7.3 -> 7
			var i1 := i0 + 1
			var j0 := int(floor(y))		# 4.8 -> 4
			var j1 := j0 + 1

			# These are fractional weights
			# They tell us how close the point is to each side of the cell
			# Consider example where our point is at (7.3, 4.8)
			# That gives us: s1 = 0.3, s0 = 0.7, t1 = 0.8, t0 = 0.2
			# Basically we extract the decimal part into s1 and t1
			# And then we put "the rest that is missing to 1.0" into s0 and t0
			# ---
			# What this tells us, is basically that:
			# the point is at 30% distance from left side and 70% distance from right side
			# which means it should be influenced stronger by the left side and less by the right side
			# Same for y dimension, the point is at 80% distance towards bottom and 20% towards top
			var s1 := x - i0
			var s0 := 1.0 - s1
			var t1 := y - j0
			var t0 := 1.0 - t1

			# With neighbouring tiles and the fractional weights calculated,
			# we now need to decide how much density we should grab from each neighbouring tile
			# based on how close we are to it (fractional weights tells us that)
			# This function does exactly that. It's a standard mathematical operation called
			# "bilinear interpolation". You might be familiar with "linear interpolation", often
			# called "lerp" in the gamedev world, which interpolates between values in a single
			# dimension (line). Bilinear interpolation does the same, except in two dimensions (lines)
			# ---
			# Notice also that we make use of the density_prev array here. That's because we
			# keep updating the density array as we iterate, so we need to "snapshot" the densities
			# before we start iterating - otherwise we would mess up results as they would keep changing
			# So density_prev is pretty much a "snapshot of density before we start modifying it"
			density[idx] = (
				s0 * (t0 * density_prev[IX(i0, j0)] + t1 * density_prev[IX(i0, j1)]) +
				s1 * (t0 * density_prev[IX(i1, j0)] + t1 * density_prev[IX(i1, j1)])
			)
```

Now, let's add a helper function to take the snapshot of density

```
func copy_density_to_prev() -> void:
	for idx in range(size):
		density_prev[idx] = density[idx]
```

And make sure our new code gets called. Replace `_process()`

```
func _process(delta: float) -> void:
	copy_density_to_prev()
	advect_density(delta)
	
	fade_density(delta)
	fade_velocity(delta)
	
	queue_redraw()
```

The effect should look something like this

TODO: fluid_sim_5 vid

---
## A drop in the ocean

[Project snapshot](https://github.com/rskupnik/godot-fluid-simulation-demo/tree/08349dcfbe079f258a7a0fcfa9d5b5acd8146f4c)

[Diff](https://github.com/rskupnik/godot-fluid-simulation-demo/commit/08349dcfbe079f258a7a0fcfa9d5b5acd8146f4c)

You know how when you drop a bit of paint into water you can see it spread around nicely? Apparently that's what fluids do - so it would be nice if our simulated fluid did the same! It's called density diffusion

To solve this, we will use what is called the Gauss-Seidel relaxation. If you want a deep mathematical defintion - look around the internet, there's plenty of stuff about it. I'm just gonna explain it with how I understand it.

What we want to do for diffusion is go for each cell, grab the average of the neighbours and add it to the density at this cell. Theoretically we could also decrease the neighbours density, but we can skip it and just let our fading effect take care of that - it will be believable enough.

Alright, but if we just do one pass - go through each cell, grab an average of the neighbours and add it to the cell's density - it will look very choppy. What we want is to repeat this process several times to smoothen this out. This is basically what Gauss-Seidel relaxation is in this context - we first guess the proper value (in the first iteration) and then continue guessing (in the subsequent iterations) until our guess approaches a believable value. It's an approximation. This works because we are working on the live density array - it is updated in each iteration, so the next iteration works on updated data, thus getting closer and closer to what the answer should be

Start with variables

```
@export var density_diffuse_rate := 0.006		# Strength of density diffusion effect
@export var density_diffuse_iterations := 20	# How many iterations when diffusing density
```

And now the implementation

```
# Diffusion simply means spreading the density to the neighbouring cells
# Think of it like putting a drop of paint in water - it will spread
# This uses what is called "Gauss-Seidel relaxation", which basically means
# we keep "guessing" (or rather approximating) the value density_diffuse_rate times
# With enough iterations, this is close enough for the simulation to be believable
func diffuse_density(delta: float) -> void:
	
	# This is the strength of diffusion effect for this frame
	# Delta is how much time passed
	# Then we have the density diffusion strength parameter
	# Finally we multiply by N squared so it square with cell size
	var a := delta * density_diffuse_rate * N * N

	for k in range(density_diffuse_iterations):		# We iterate 20 times
		for j in range(1, N + 1):
			for i in range(1, N + 1):
				var idx := IX(i, j)

				density[idx] = (
					density_prev[idx] +				# This is the "anchor" - the original value at this cell, which stays constant throughout iterations (hence called "anchor")
					a * (							# Here we multiply the strength of the effect with the sum of densities of all neighbours - this is the heart of "Gauss-Seidel" relaxation
						density[IX(i - 1, j)] +		# These are
						density[IX(i + 1, j)] +		# the four
						density[IX(i, j - 1)] +		# neighbours
						density[IX(i, j + 1)]		# :)
					)
				) / (1.0 + 4.0 * a)					# This balances the math, since we add densities from 5 cells (this one + 4 neighbours). Without this, the density would grow too much (try it!)
 ```

 Don't forget to update `_process()`

 ```
 func _process(delta: float) -> void:
	copy_density_to_prev()
	diffuse_density(delta)
	
	copy_density_to_prev()
	advect_density(delta)

	fade_density(delta)
	fade_velocity(delta)

	queue_redraw()
```

And now we can see this nice diffusion effect. Remember you can hold left mouse button and move around in small circles to keep adding density in a single cell

TODO: fluid_sim_6 vid

---
## Set some boundaries