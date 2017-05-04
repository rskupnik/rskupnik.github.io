---
layout: post
title: TDD, Spock and Groovy on a real use case example
---

**TDD** stands for **test-driven development**. The concept is very simple: given a **specification**, you first write **tests** that fulfil that specification and **fail** (because there is no implementation) and then implement code to make the tests **pass** (and thus, satisfy the specification).

In my professional experience, TDD is a useful concept but difficult to use when faced with an old, robust codebase. It's fun and neat when creating something from scratch or when the business it not overly complicated yet, but is very hard to introduce to a years-old project with heavy technical debt.

One concept from the title out of the way, let's introduce **Spock** now. [Spock](http://spockframework.org) is a Groovy-based library for testing. We will use Spock to write tests that satisfy our specification. The standard go-to library when using Java is [JUnit](http://junit.org/junit4/) (most often paried with [Mockito](http://site.mockito.org/)) but I find **Spock** quite more powerful and easier to write and read the test cases.

Alright, everything fine and dandy, but what is this **Groovy** thing? [Groovy](http://groovy-lang.org/) is a programming language that compiles for the JVM. In simple terms - whether you write in Java or in Groovy - the **compiled output** is the same and can be ran on the JVM. Why use it then, if the output is the same? Well, mainly because it introduces many useful concepts that are not present in Java. *Why does everyone use Java then and not Groovy with those new concepts then?* - because Java is established, stable and widely adopted. But let's not go too deeply into this.

Now, there's like five keywords and four of them with links that I've just thrown at you. If it's the first time you read about them, you might feel quite overwhelmed. So let's recap what we will do with Wordplay in one sentence:

> We will use **TDD** (test-driven development) when working on Wordplay, using the **Spock** library, which is written in the **Groovy** language, instead of the standard **JUnit** + **Mockito** libraries combo.

And just to help you categorize the keywords:
- Development processes: TDD
- Libraries: Spock, JUnit, Mockito
- Languages: Java, Groovy

---

Moving on to Wordplay. If you perhaps remember from the [previous post](/wordplay-word-processing-engine) - Wordplay is a simple word processing engine that should cover my needs for The Story game. More details on how it's meant to work in the mentioned post.

Because it's a new, small piece of software and because the specifications are clear, using the TDD development process here is practically a no-brainer.

Brace yourselves. I'm about to throw a small snippet of code at you that has a lot of concepts packed in it.

```groovy
1 class WordplayTernaryTest extends Specification {
2
3    final Wordplay wordplay = new WordplayImpl();
4
5    def setup() {
6        wordplay.reset()
7    }
8
9    //region Shorthand Ternary Expressions
10   @Unroll
11   def "should resolve shorthand ternary expression given variable: #var"() {
12       given:
13       String script = "It was a {weather_sunny ? sunny | rainy} day."
14
15       when:
16       wordplay.setVariable("weather_sunny", var);
17       String output = wordplay.process(script)
18
19       then:
20       output.equals(result)
21
22       where:
23       result                | var
24       "It was a sunny day." | true
25       "It was a rainy day." | false
26   }
27   //endregion
28
29 }
```

Ok, there are a few things at play here. Let's go by this snippet line by line.

In **line 1** we have a straightforward Groovy class that extends *Specification* - a class provided by Spock. Extending this class is what defines that our `WordplayTernaryTest` is a suite of tests.

In **line 3** we initialize the object that we will run our test against. In our case, it's a implementation of the `Wordplay` interface. Our variable type is interface because we should always run the tests against an interface.

The `setup()` function at **line 5** will run before each test. In our case, we simply want to reset the state of the `wordplay` object so it's clean before each new test. We could create a `new WordplayImpl()` each time here (if the variable was not final) but I like `reset()` more.

The weird coment at **line 9** is something specific for the IntelliJ IDE. IntelliJ will interpret this pair of comments (`//region X` and `//endregion`) as a **named code region** and allow folding. It will look like this:

![IntelliJ region]({{site.baseurl}}/public/images/intellij-region.png)
*There's something odd about those line numbers...*

It's a neat feature but you must be aware that it only works in IntelliJ IDE. If you heave colleagues working in a different IDE, you should probably not use those comments as it will not work for them and will just look weird.

We will get back to the `@Unroll` annotation at **line 10** later.

At **line 11** there's a function definition. Testing libraries (such as Spock) usually work in such a way that a single class is a suite of tests and each method is a separate test. What we have here at line 11 is a method declaration and there are two new concepts here if you're unfamiliar with Groovy. **First of all** - we can use a string as the name of our method. **Second of all** - Spock allows us to bind a variable used in the test to the method name (`#var`), which will be useful paired with the aforementioned `@Unroll` annotation. It will become clear once we get back to what `@Unroll` does.

There is a trend in TDD which says that test names (method names) should be **descriptive**. The name of your method should describe what the test does. This is where Spock & Groovy pair have an advantage over Java & JUnit. We can use human-readable strings to name our methods/tests, while in Java we would use monstrosities such as `public void should_resolve_shorthand_ternary_expression_given_variable()`. Pretty scary.