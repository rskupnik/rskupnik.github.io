---
layout: post
title: I've just learned Rust and I think I'm in love
---

I've decided to learn some Rust during the last weeks along working on the [Stanford's experimental course on operating systems](http://web.stanford.edu/class/cs140e/).

> Rust is a systems programming language that runs blazingly fast, prevents segfaults, and guarantees thread safety.

That's how the language is described on [its website](https://www.rust-lang.org). Here's a list of things that I think are great about it.

### Rust employs many innovative concepts that make sense

There are many things that make this language stand out in the crowd and they all make sense when you think about them in the scope of Rust's main goal - a safe alternative for systems programming. Things such as [ownership](https://doc.rust-lang.org/book/second-edition/ch04-00-understanding-ownership.html), [borrowing](https://doc.rust-lang.org/book/second-edition/ch04-02-references-and-borrowing.html), [slices](https://doc.rust-lang.org/book/second-edition/ch04-03-slices.html), [modules](https://doc.rust-lang.org/book/second-edition/ch07-00-modules.html), [lifetimes](https://doc.rust-lang.org/book/second-edition/ch10-00-generics.html) - just to name a few.

### It has a built-in package manager

It's called Cargo and it's great, let me just quote [its online book](https://doc.rust-lang.org/cargo/):

> Cargo is the Rust package manager. Cargo downloads your Rust project’s dependencies, compiles your project, makes packages, and upload them to crates.io, the Rust community’s package registry.

A simple to use and browse [registry of crates](https://crates.io/) is important to encourage creation of a robust collection of user-made libraries, easy to find and incorporate into your project. It worked for Java, it works here as well.

### Easy installation

You just go to [https://rustup.rs/](https://rustup.rs/) and that's pretty much all. Updating and removal is just as easy, since we get a `rustup` tool that handles that for us. Simple and fast, no time wasted reading several pages of doc just to get the thing installed.

### Complicated and powerful but yet easy to obtain and well documented

As mentioned in the first point, the language introduces a few advanced concepts which might be hard to wrap your head around at first. Luckily, there's [the online book](https://doc.rust-lang.org/book/second-edition/ch01-00-introduction.html) which serves as a great first-contact material, plus [a few other books](https://doc.rust-lang.org/) for additional reading. Then there's [Rust Learning](https://github.com/ctjhoa/rust-learning), a collection of materials to learn Rust.

### Documentation is a first-class citizen

I really like this one - creators of Rust clearly consider documentation of your code just as important as the code itself - and it makes it so much easier to understand other people's modules. It's especially important in an environment where creating and sharing your code is encouraged.

Rust uses the known notion of [doc-comments](https://doc.rust-lang.org/book/first-edition/documentation.html) which let you incorporate the documentation of your code along it and use a tool to generate the html docs. That's cool and all, we already have this in other languages (like Java's javadoc, to not search too far) but it needs to be mentioned that **`rustdoc` recognizes Markdown!** Not only that, **any code examples in `rustdoc` are treated like tests and get executed during compilation!** That ensures that your examples are not obsolete (or at least that they compile).

### Supports the open source culture by always including sources in your crates

Not much more to say about it - any code you write and publish with `cargo` onto [crates.io](https://crates.io/) will have source code included inside. You can read more about that [here](https://doc.rust-lang.org/book/second-edition/ch14-02-publishing-to-crates-io.html).