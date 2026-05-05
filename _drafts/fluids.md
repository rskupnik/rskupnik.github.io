---
layout: post
title: Fluid simulation explained with Godot game engine
published: false
---

When I first stumbled upon fluid simulations in game dev I was amazed on how good the effect could be. I really wanted to learn how this works, but learning materials on this topic are suprisingly sparse - and those which I found were pretty difficult to understand. Nonetheless, I decided to give it a try; and - while I'm at it - why not create a blog post out of it to hopefully make it easier for the next guy?

Before we begin, I want to stress a few points:
* I'm not a maths guy. If you find errors in my explanations, please DM me on Bluesky or send an email and I'll correct it
* I don't FULLY understand everything that goes on here. I feel like I understand a lot, certainly enough to make use of this, but I won't pretend I know all the details
* This implementation is for learning purposes only. For that reason it is implemented in a way that is not the best performance-wise. Calculations are made solely on the CPU. We introduce way too many variables. All of that to make it easier to read and learn

Learning materials I used:
* "Real-Time Fluid Dynamic for Games" by Jos Stam (PDF)
* ["Fluid Simulation for Dummies" by Mike Ash](https://www.mikeash.com/pyblog/fluid-simulation-for-dummies.html)

You can all of the code in this repository: [github.com/rskupnik/godot-fluid-simulation-demo](https://github.com/rskupnik/godot-fluid-simulation-demo)

I tried using git commits to mark code checkpoints matching the post, so if you don't want to write the code along me and still would like to see how the project should look like at a given stage of this project then use the [commit view](https://github.com/rskupnik/godot-fluid-simulation-demo/commits/master/). Just click the arrows on the right to see the repository at the point of a particular commit. I'll drop links to make it easier at the start of each chapter.

---
## AI Disclosure

Every word of this blog post and every line of this codebase is written by me.

AI was only used for research.

---
## The journey begins with a grid

[Project snapshot](https://github.com/rskupnik/godot-fluid-simulation-demo/tree/0a755f8eb80a56cb990f68b95356f38445770bb3)

The algorithms we will use are based on physical equations for fluid flow - the Navier Stokes equations. Our use case is a game dev one - so we want to sacrifice precision of these calculations for speed. The effect needs to be good enough but not overly expensive. We achieve this with three ways. First of all, we use a relatively small grid with large cells. Second - we advance the simulation in arbitrary time steps. Finally, we use approximation equations (such as Gauss-Seidel relaxation) to arrive at good-enough solutions to some equations.