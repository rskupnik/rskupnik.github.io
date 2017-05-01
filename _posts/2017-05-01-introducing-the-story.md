---
layout: post
title: Introducing The Story - a modern text-based RPG
---

*The Story* (or *Opowieść*, in Polish) is a game I've wanted to create since I was a kid. The idea of harvesting the power of human imagination to turn simple text into vivid imagery has always fascinated me. I've always liked writing stories; and I liked creating and playing games - so being able to combine the two would be a dream come true to me.

Now, when you hear the term "text-based game" you probably conjure images like such.

![Otchłań]({{site.baseurl}}/public/images/otchlan_1.jpg)
*Ain't those some pretty letters, though incomprehensible to most of you :)*

This screenshot is from the game [Otchłań](http://otchlan.pl/) - a Polish Single User Dungeon game.

All such text-based games share some common features:
- You play them in a console
- They use text only and sometimes some sounds/music
- You interact with them using *commands* that you type into the console
- They rely on imagination heavily

This kind of games blossomed long ago, when we did not have fancy graphics cards and thousands of megabytes of RAM. I find them very unique in today's world of photorealistic 3D graphics - those text-based games tap directly into your brain and **make it, your mind, your graphics card**.

When playing such games though, I've always had one particular problem - everything was dark. I couldn't help it. The environment of such games - coloured text in an ocean of black - made my mind imagine the presented world in dark colours. I had problems imagining a sunny day scene when the text that described that scene was drowning in the sea of black.

I had more similar issues that could not be helped back in the days. Therefore, when thinking about early concepts of **The Story** I stopped and thought: *we have the year 2017, why would I stick to that ugly console. Those games back in their times had little choice, but now there's plenty of better options*.

So I've decided to add the very important keyword to my game concept: **modern**. I would like to utilize some more powerful techniques to enhance the text-to-imagination effect apart from just raw storyline. Some examples include:
- **A dynamic/interactive background**. Imagine text being displayed with a texture of a bricked wall behind it (with right contrast, of course) when describing a scene happening in a small, medieval town alley. Sounds boring? Add [normal mapping](https://learnopengl.com/img/advanced-lighting/normal_mapping_compare.png). Still not it? Imagine the scene happening in a dungeon instead and your cursor being a torch that lights up the cracks in the wall as you read the story of descending down the dark staircase with just a torch in your hand.
- **Actual interaction**. The old text-based games were constrained by technology so their interaction possibilities were very limited. Fights, for example, would go like this: type a *kill* command and watch some text fly on the screen that described your and your opponents damage on each other - until the fight is over. Pretty boring. I want to make the game interactive - there will be **no commands whatsoever**. You would interact with the game by clicking keywords in the text and choosing an action from a context menu. Less important dialogues by some ambient NPCs would be displayed in speech bubbles. The combat system would require constant interaction from the player and some actual engagement and skill to win the fight.
- **Some non-intrusive images to help set the mood**. The game is still text-based and so it will remain, but some images can facilitate conjuring the described scene in your imagination. Think about those drawings in books. In our case, I'd like to add an image header above the text that will indicate stuff like time of day and weather. Perhaps it can be combined with some lighting technique applied to the background to enhance the effect - not sure yet, but I think it's worth trying :)
- **Sounds and music**. This might be hard to achieve, I definitely suck when it comes to this topic, but it would be great to have some non-intrusive background music and sounds of doors squeaking or rainfall would also be quite nice, me thinks.
- **Effects!** Things like a slight screen shake when a particularly huge troll approaches you (that would be useful for reddit, I should suggest that somewhere). A magic book in the text could be displayed with some glowing letters. If you eat a weird looking mushroom from and old guy in a back alley (don't do that) the text starts acting weird, the letters are scrambled with only the first and the last one being correct, etc. Lots of possibilities here, just need to try to not go over the top :)
- **Living world**. This is a concept I really like. I even designed a specially-crafted text processor to make it happen (called **Wordplay**, I'll create a separate post on it). The idea is that we want the world to **pretend to be alive in as much realistic manner as possible**. Time of day and weather will change and that will be indicated not only on the header image, but also the text itself will change. On a sunny day you'll be *standing in a beautifully illuminated great hall of a Random Temple*, while on a rainy, foggy day you'll be *standing in a great hall of a Random Temple, rain drops hitting the round ceiling making a constant, ambient noise*. Slight changes like that which will make you feel like the world is actually changing and you're a part of it. A bigger problem when it comes to the living world concept is making NPCs feel alive. Making each NPC have his own life schedule and interactions with other NPCs might easily bloat to 90% of work totally spent on the whole game, therefore I believe I need to settle at some point on the boring<--->superb scale that is both satisfactory enough and not very time consuming.

Alright, if you've managed to go through all that wall of text, I believe you deserve some image.

![Opowieść/The Story]({{site.baseurl}}/public/images/opowiesc_1.png)
*The English is bad in this one, I know, okay?*

This is a very early concept. The background is black but it's ok since it's night time :P Really though, as I mentioned, the background will be more dynamic, it's just black on this particular concept. Most of the time, the *default* background would probably be the same as the avatar background is, the one above my nickname.

The arrows are there to move around by clicking them instead of typing *north*, *south*, etc.

The blue text at the bottom will display short-lived events happening right now, like something howling in a distance or some NPC giving you a strange look. They'll *float-up* as they happen, linger for a few seconds for you to read and then *fade-away* or *float-away* to make space for other events. They are there to make the world feel more alive.

I have not yet settled on what stats will your character possess so the menu on the right is just a filler for the time being.

The weird thing at the top of the right menu is a filler for the minimap.

Also, have I mentioned I plan to make the game available for Android as well? :) That's a topic for a future post.

**That's pretty much it for the introduction**. There's some more concepts to talk about, that did not make it to this post, and which I might describe in some later posts:
- Combat system in detail
- Character progression
- Storyline
- Monetization
- Multiplayer
- Choice-driven story
- Wordplay, the text processing engine behind the living world
- Many more...