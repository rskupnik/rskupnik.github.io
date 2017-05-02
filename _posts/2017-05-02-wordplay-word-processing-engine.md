---
layout: post
title: Wordplay - a word processing engine for The Story
---

**Wordplay** is the name I came up with for a text processing engine to be used in **The Story**.

The capability I need from this text processor is quite simple, it needs to do three things:
- Transform text based on some changing variables
- Indicate parts of text that should have some effects applied to
- Contain some additional data that might influence how the scene is treated

Wordplay achieves that with the following features:
- Text transformation based on attached variables
- Object injection (both external and internal)
- Attaching external variables
- Emitting objects with parameters

That's pretty much it. Those simple features should be enough for Wordplay to fulfil its purpose.

---

Before we go into details I'd like to mention the **order of execution**. The current version of **Wordplay** only has two stages:
1. Injection
2. Processing

The order is important because it means you can inject valid Wordplay script that will be processed just as any other valid Wordplay script already included.

Alright, here come some screenshots and explanations.

![Wordplay]({{site.baseurl}}/public/images/wordplay_1.png)

In the **first** line, we have a classic ternary expression. Based on the boolean value of the variable *weather_sunny* we output either *sunny* or *rainy*. A keen mind might think at this point - what if I can have multiple weather conditions in my game, do I need to provide a *weather_xxx* for each of those and set them accordingly? Well, no, the ternary expression on the screenshot is a *shorthand* version, the full version includes a value that the variable should have:

`{weather:sunny ? sunny|weather:rainy ? rainy|weather:cloudy cloudy|pleasant}`

Here we change the text appropriately based on the exact value of the variable *weather* with a fallback value *pleasant*. As you might have noticed, there are no spaces between the "\|" symbols, because if there were - those spaces would be outputted along with the text. I think it makes it quite hard to read though, so I might consider an optional setting that would allow setting spaces before and after "\|" symbols that would be stripped before outputting the text. The expression should then be quite more readable:

`{weather:sunny ? sunny | weather:rainy ? rainy | weather:cloudy cloudy | pleasant}`

The **second** line represents an **externally injected object**. The logic here is simple - the external system using this particular Wordplay script needs to provide something to be injected at this place and so it shall be injected. As injection happens first, the external system can inject valid Wordplay code here that will be parsed just as any other. In our example, we would probably inject something such as *tall guard* or *tired guard*, depending on how long the guard's been standing there :)

The **third** line represents an **internally injected object** and is really used for readability only. It works the same as externally injected objects, except that the payload to be injected is provided in the script itself, below the **delimiter**, instead of being provided by an external actor.

The **fourth** line represents an **anchored emitted object**. By anchored, we mean that this object has a fixed position in the text - in our case, it's attached to the word *vibrating*. This word will have some key - value pairs attached to it that can be used by the external system to render it with some special effects - in this case the word *vibrating* printed on the screen would probably be tinted blue and slightly vibrating.

The **fifth** line is a **delimiter** that separates the transformed text from pure Wordplay code to be self-applied. It will probably be configurable as some texts might want to use the "$" symbol.

The **sixth** line, below the delimiter, is a compliment to the **third** line. It represents the value that should be injected. Again, because injection happens before processing, valid Wordplay script can be injected and will be parsed as any other.

By utilizing the **internal object injection** mechanism, we can make the text much more readable by separating code from data:

![Wordplay]({{site.baseurl}}/public/images/wordplay_2.png)

All the code has been moved below the delimiter and the text itself only containes indexed internally injected objects. Yet again, this is possible because **injection happens before processing**.

Additional feature presented on this screenshot is **object emission**. *But we already did have emitted objects on the fourth line of the previous example!* - you might say. You're right, but that was an **anchored** object - attached to a particular part of text. What we have here are **non-anchored emitted objects**, or, in simple words, just some simple meta data to be emitted and attached to the whole scene. We can use it to attach some data to the scene in the form of a key - value map or a list. We could, for example, emit a map called *properties* with a *fighting_allowed*:*true* key - value pair, which can be interpreted by the external actor accordingly.

---

That's pretty much it for the first version of **Wordplay**. I have a bad feeling in my stomach that I have missed something important in this design that will come out during implementation and bite me hard :) Not a reason to stop trying, though!

I will post a link to the github project here as soon as I actually start implementing it :)

See you in the next post, and remember to have fun! :)