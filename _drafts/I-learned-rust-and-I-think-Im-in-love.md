---
layout: post
title: I've just learned Rust and I think I'm in love
---

I've decided to learn some Rust recently while working on the [Stanford's experimental course on operating systems](http://web.stanford.edu/class/cs140e/).

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

As mentioned in the first point, the language introduces a few advanced concepts which might be hard to wrap your head around at first. These are there for a reason though, and learning about them might make you look at your code quite differently.

And learn you can, if not from [the online book](https://doc.rust-lang.org/book/second-edition/ch01-00-introduction.html), which serves as a great first-contact material, then perhaps from [some of the others](https://doc.rust-lang.org/). Then there's [Rust Learning](https://github.com/ctjhoa/rust-learning), a collection of materials to learn Rust. Pair that with the easy installation and you're ready to start trying out those concepts in practice in no time.

### Documentation is a first-class citizen

I really like this one - creators of Rust clearly consider documentation of your code just as important as the code itself - and it makes it so much easier to understand other people's modules. It's especially important in an environment where creating and sharing your code is encouraged.

Rust uses the known notion of [doc-comments](https://doc.rust-lang.org/book/first-edition/documentation.html) which let you put the documentation of your code alongside it and use a tool to generate the html docs. That's cool and all, we already have this in other languages (like Java's javadoc, to not search too far) but it needs to be mentioned that **`rustdoc` recognizes Markdown!** Not only that, **any code examples in `rustdoc` are treated like tests and get executed during compilation!** That ensures that your examples are not obsolete (or at least that they compile).

### Supports the open source culture by always including sources in your crates

Not much more to say about it - any code you write and publish with `cargo` onto [crates.io](https://crates.io/) will have source code included inside. You can read more about that [here](https://doc.rust-lang.org/book/second-edition/ch14-02-publishing-to-crates-io.html).

### Makes you think about your code in ways you've probably not thought before

That's mainly due to [ownership](https://doc.rust-lang.org/book/second-edition/ch04-00-understanding-ownership.html), [borrowing](https://doc.rust-lang.org/book/second-edition/ch04-02-references-and-borrowing.html) and [lifetimes](https://doc.rust-lang.org/book/second-edition/ch10-00-generics.html). How often do you wonder about the scopes of your variables and how many mutable and immutable references do they have at any given moment? Yeah.

### It's fast

Not only is it fast to write the code, it's also fast to run it:

> By striving for zero-cost abstractions, higher level features that compile to lower level code as fast as code written manually, Rust endeavors to make safe code be fast code as well.

### Serious approach to testing

Unit testing is crucial when it comes to making sure your code works as it's supposed to and pave the ground for potential refactors, there's probably no need to convince anyone of that. If you agree then you'll be happy to know how easy it is to [write tests](https://doc.rust-lang.org/book/second-edition/ch11-01-writing-tests.html), [run them](https://doc.rust-lang.org/book/second-edition/ch11-02-running-tests.html) and [organize them](https://doc.rust-lang.org/book/second-edition/ch11-03-test-organization.html) in Rust.

### Combines what's best in other languages (be it old or new) and avoids their mistakes

* Doc-comments!
* Functional elements (closures!)
* No class-inheritance
* Traits!
* Avoid a lot of dangerous bugs so easy to make in C/C++
* And many more for you to discover...

### Convention over configuration where it makes sense

Not a new concept, convetion-over-configuration makes it much more pleasant to work with a language, **if done right**. It's easy to overdo it or to lose distance and make the convention part make sense to the creators, but necessarily the users. I believe Rust strikes the balance here quite well, although this is one of those things that you get to know with experience, and I don't have a lot of that with Rust yet.

Some examples: [organization of modules](https://doc.rust-lang.org/book/second-edition/ch07-01-mod-and-the-filesystem.html), aforementioned [tests](https://doc.rust-lang.org/book/second-edition/ch11-03-test-organization.html) or [configuration of workspaces](https://doc.rust-lang.org/book/second-edition/ch14-03-cargo-workspaces.html) to name just a few.

### Tooling that's easy to use, powerful and extensible.

[Cargo](https://doc.rust-lang.org/cargo/) is the main tool you'll use for compiling, running and deploying your code. It's well documented, easy to use and it's output messages are pleasant to read. Seriously, I wish all languages had such **clear compiler warnings and errors** that not only **tell you what and where**, but also **give hints** on what you might have done wrong - and they are **clearly meant for users**.

![Rust compiler error]({{site.baseurl}}/public/images/rust_error.png)
![Rust compiler warning]({{site.baseurl}}/public/images/rust_warn.png)

Oh and have I mentioned it's easily [extensible](https://doc.rust-lang.org/book/second-edition/ch14-05-extending-cargo.html)? Quoting the book:

> Cargo is designed so you can extend it with new subcommands without having to modify Cargo. If a binary in your `$PATH` is named `cargo-something`, you can run it as if it was a Cargo subcommand by running `cargo something`. Custom commands like this are also listed when you run `cargo --list`. Being able to use `cargo install` to install extensions and then run them just like the built-in Cargo tools is a super convenient benefit of Cargo’s design!

### Ownership, immutability and type system make it easy to support concurrency

*Fearless concurrency*, as the Rust folk call it. Again, the [relevant chapter](https://doc.rust-lang.org/book/second-edition/ch16-00-concurrency.html) describes it best:

> By leveraging ownership and type checking, many concurrency errors are compile time errors in Rust rather than runtime errors. Therefore, rather than you spending lots of time trying to reproduce the exact circumstances under which a runtime concurrency bug occurs, incorrect code will refuse to compile and present an error explaining the problem. As a result, you can fix your code while you’re working on it rather than potentially after it has been shipped to production. We’ve nicknamed this aspect of Rust fearless concurrency.

### It's easy to spot the "unsafe" parts

Rust does give you a lot of memory safety guarantees that are **enforced at compile time**, but sometimes there are things that just require you to step in, seize control and tell Rust to loosen up a notch - especially when dealing with embedded systems. You can do that by using the [`unsafe` keyword](https://doc.rust-lang.org/book/second-edition/ch19-01-unsafe-rust.html) to create a block of code where Rust will not be so strict about its security paranoia (but will still provide some of it). Thanks to that you can **extract the necessarily unsafe parts** of your code into as small pieces as possible and make them **clearly visible**, indicating they need to be handled with caution.

---

Those are the things I really like about Rust - even though I'm just a beginner, a newcomer to this strange land of borrows, ownership, lifetimes and fearless concurrency. The language is evolving intensively, new features are added and the old ones get refined all the time - and it's all well described and easy to keep track of - and, thanks to the `rustup` tool, you can switch between versions without headache.

I think it's safe to say that Rust does seem like a **solid alternative** to some of C++'s uses - and is **strongly worth considering**.

If you're mesmerized by those strange wonders just like I am, you might want to start with the second edition of [*The Rust Programming Language* book](https://doc.rust-lang.org/book/second-edition/ch01-00-introduction.html) - it's smooth to read and serves as a nice entry point.