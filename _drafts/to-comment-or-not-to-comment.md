---
layout: post
title: To comment, or not to comment
---

---

When working in professional Java projects or looking through open source projects, we can come across several styles of commenting code and various opinions on how it should be done. Some people like to insert pseudocode-like comments everywhere they can, others claim that commenting should be avoided at all costs as it's a sign of poor design. Let's have a look at what tools does Java give us when it comes to commenting code and then let me share with you my opinion on when and how to use them.

---
## How to comment

The official Java Comment Conventions can be found [at Oracle's website](http://www.oracle.com/technetwork/java/codeconventions-141999.html). The document is quite old, but still valid. If you want to find more details on anything I write about in this section, see that link. This section is basically a summary of that document, all quotes come from there.

Java gives us two kinds of comments: **implementation** and **documentation** comments.

> Implementation comments are meant for commenting out code or for comments about the particular implementation. Doc comments are meant to describe the specification of the code, from an implementation-free perspective, to be read by developers who might not necessarily have the source code at hand.

In other words, **documentation** comments are what we commonly know as **Javadoc**. Let's have a look at what particular types of comments does the official documentation describe.

### Block comments

> Block comments are used to provide descriptions of files, methods, data structures and algorithms. Block comments may be used at the beginning of each file and before each method. They can also be used in other places, such as within methods.

```java
/*
 * This is a block comment
 */
```

### Single-line comments

> Short comments can appear on a single line indented to the level of the code that follows. If a comment can't be written in a single line, it should follow the block comment format

```java
/* This is a single line comment */
System.out.println("Hello, World!");
```

### Trailing comments

> Very short comments can appear on the same line as the code they describe, but should be shifted far enough to separate them from the statements. If more than one short comment appears in a chunk of code, they should all be indented to the same tab setting.

```java
System.out.println("Hello, World!");	/* This is a trailing comment */
```

### End-of-line comments

> The // comment delimiter can comment out a complete line or only a partial line. It shouldn't be used on consecutive multiple lines for text comments; however, it can be used in consecutive multiple lines for commenting out sections of code.

```java
// Print 'foo'
System.out.println("foo");

//if (bar) {
//	System.out.println("bar");
//}

return false;		// Explain why false is returned
```

### Documentation comments

> Doc comments describe Java classes, interfaces, constructors, methods, and fields. Each doc comment is set inside the comment delimiters /\*\*...\*/, with one comment per class, interface, or member.

```java
/**
 * This is a javadoc comment. Notice the double * at the opening, which distinguishes it from a block comment.
 */
```

## When to comment

Comments are probably the easiest part of a programming language's syntax - but knowing **when** to comments is the tricky part.

I usually come across two kinds of people when it comes to commenting code - the **anti-commenters** and the **overcommenters**.

**Anti-commenters** are people who claim that **any** comments are symptom of bad design and will happily flag them in any code review they encounter without giving a second thought on why are they there. I understand where they are coming from but I disagree with the absolute no-comments rule. 

**Overcommenters** are usually young developers with little experience. Overcommenting in such a case stems from the fact that they find it easier to describe the work they need to do in pseudo-code comments first and then fill it with actual code. I believe it's a good practice, it takes the load off one's mind and makes it easier to focus at particular pieces of a whole - but such comments should be removed at the ned and the code needs to explain by itself what it does - through proper class and functions names and other means.

When it comes to commenting I personally look at **two rules**:
* Explain the context - **describe not what a partiular piece of code does, but why does it do what it does**
* **Don't repeat information** - in a piece of code like `List<String> names = new ArrayList<String>();` it is obvious what the list is for, there's no need to add `// Create a list to hold names`

The technique I use for deciding whether or not a piece of code should have some comments is very simple - put yourself in the shoes of a person who reads your code. Assume you're a developer that just got assigned to the project, you have no idea about the system as a whole, about all the different modules working on different servers and integrating with each other; about conventions and terminology assumed in the project. Imagine reading your code as such a person and focus on one thing - what **context** would you need to know to understand the code better?

For example, you might have a large listener class that reads events from a `RabbitMQ` Queue and does a lot of business logic on them. Perhaps it would be useful to add a block comment at the top of the class explaining what the queue is for in terms of business logic, in what other microservice is the queue populated with events and what do the events represent (again, in terms of business logic). This information can make it a lot easier to understand your code, because you suddenly know **what is the purpose** of the code, not only what it **technically does**.

Of course, such a block comment might (and probably will) get outdated after a while. People will make changes to the code and not update the block comment at the top, etc. However, that's the reason why you should not describe **implementation details** but just the **overall context**, which is not **subject to change**. In our example, describing what the events represent is pretty safe - if at some point the architecture shifts from a queue implementation to something else, your listener will probably be removed anyway and your block comment deemed obsolete alongside it.