---
layout: post
title: TDD with Spock, Groovy and Java
---

---
## Introduction

[**TDD**](https://en.wikipedia.org/wiki/Test-driven_development) stands for **test-driven development**. The concept is very simple: given a **specification**, you first write **tests** that fulfil that specification and **fail** (because there is no implementation) and then implement code to make the tests **pass** (and thus, satisfy the specification).

In my professional experience, TDD is a useful concept but difficult to use when faced with an old, robust codebase. It's fun and neat when creating something from scratch or when the business it not overly complicated yet, but is very hard to introduce to a years-old project with heavy technical debt.

One concept from the title out of the way, let's introduce **Spock** now. [Spock](http://spockframework.org) is a Groovy-based library for testing. We will use Spock to write tests that satisfy our specification. The standard go-to library when using Java is [JUnit](http://junit.org/junit4/) (most often paried with [Mockito](http://site.mockito.org/)) but I find **Spock** quite more powerful and easier to write and read the test cases.

Alright, everything fine and dandy, but what is this **Groovy** thing? [Groovy](http://groovy-lang.org/) is a programming language that compiles for the JVM. In simple terms - whether you write in Java or in Groovy - the **compiled output** is the same and can be ran on the JVM. *Why use it then, if the output is the same?* Well, mainly because it introduces many useful concepts that are not present in Java. *Wait, then why does everyone use Java and not Groovy with all those new concepts?* - because Java is established, stable and widely adopted. But let's not go too deeply into this.

There's like five keywords, and four of them with links, that I've just thrown at you. If it's the first time you read about them, you might feel quite overwhelmed. So let's recap what we will do in one sentence:

> We will use **TDD** (test-driven development) when working on Wordplay, using the **Spock** library, which is written in the **Groovy** language, instead of the standard **JUnit** + **Mockito** libraries combo.

Do you remember [Wordplay](/wordplay-word-processing-engine)? It's a library I'm making for my game, [The Story](/introducing-the-story), which I've decided to implement using TDD, and, while at it, describe how TDD works in the post you're reading right now :)

Before we move to implementation, just to help you categorize the keywords (the ones we'll use in this post in **bold**):
- Development processes: **TDD**
- Libraries: **Spock**, JUnit, Mockito
- Languages: **Java**, **Groovy**

---

##  Setup

I assume you're familiar with how to setup a project in Maven. If not, there's plenty of tutorials out there, which will probably explain this much better then I would.

We need to add two things to our Maven project: **the Spock dependency**, obviously, and a **Groovy compiler plugin**, which will allow Maven to compile Groovy code.

This goes into the `<dependencies>` section:

```xml
<dependency>
  <groupId>org.spockframework</groupId>
  <artifactId>spock-core</artifactId>
  <version>1.1-groovy-2.4-rc-3</version>
  <scope>test</scope>
</dependency>
```

The version will most likely by different by the time you're reading this :) We also only need Spock during testing, hence the `<scope>test</scope>`.

And this goes into the `<plugins>` section:

```xml
<plugin>
  <groupId>org.codehaus.gmavenplus</groupId>
  <artifactId>gmavenplus-plugin</artifactId>
  <version>1.5</version>
  <executions>
    <execution>
	  <goals>
	    <goal>compile</goal>
	    <goal>testCompile</goal>
	  </goals>
    </execution>
  </executions>
</plugin>
```

The plugin will step into the `compile` and `testCompile` goals and will recognize and compile Groovy code.

---

## Implementation

If you perhaps remember from the [previous post](/wordplay-word-processing-engine) - Wordplay is a simple word processing engine that should cover my needs for [The Story](/introducing-the-story) game. More details on how it's meant to work in the mentioned post.

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

In **line 1** we have a straightforward Groovy class that extends `Specification` - a class provided by Spock. Extending this class is what defines that our `WordplayTernaryTest` is a suite of tests.

In **line 3** we initialize the object that we will run our test against. In our case, it's a implementation of the `Wordplay` interface. Our variable type is interface because we should always run the tests against an interface.

The `setup()` function at **line 5** will run before each test. In our case, we simply want to reset the state of the `wordplay` object so it's clean before each new test. We could create a `new WordplayImpl()` each time here (if the variable was not final) but I like `reset()` more.

The weird coment at **line 9** is something specific for the IntelliJ IDE. IntelliJ will interpret this pair of comments (`//region X` and `//endregion`) as a **named code region** and allow folding. It will look like this:

![IntelliJ region]({{site.baseurl}}/public/images/intellij-region.png)
*There's something odd about those line numbers...*

It's a neat feature but you must be aware that it only works in IntelliJ IDE. If you heave colleagues working in a different IDE, you should probably not use those comments as it will not work for them and will just look weird.

We will get back to the `@Unroll` annotation at **line 10** later.

At **line 11** there's a function definition. Testing libraries (such as Spock) usually work in such a way that a single class is a suite of tests and each method is a separate test. What we have here at line 11 is a method declaration and there are two new concepts (if you're unfamiliar with Groovy). **First of all** - we can use a string as the name of our method. **Second of all** - Spock allows us to bind a variable used in the test to the method name (`#var`), which will be useful paired with the aforementioned `@Unroll` annotation. It will become clear once we get back to what `@Unroll` does.

There is a trend in TDD which says that test names (method names) should be **descriptive**. The name of your method should describe what the test does. This is where Spock & Groovy pair have an advantage over Java & JUnit. We can use human-readable strings to name our methods/tests, while in Java we would use monstrosities such as `public void should_resolve_shorthand_ternary_expression_given_variable()`. Pretty scary.

What you see at **lines 12, 15, 19 and 22** are Blocks - a concept introduced by Spock. These keywords split your test method into predefined blocks, which makes it easier to read and allows for some degree of validation whether what you do in the block really belongs here. In the **given** block, we setup all data that's needed for this test, the **when** block is were we trigger what we want to be tested, the **then** block contains validation whether the test was successful or not and the **where** block contains a special construct, which, together with `@Unroll`, lets us **define several tests that share the same setup in a single method**.

Simply stated, the **where** block defines the *moving parts*, so to speak, of our test. All the other code remains static - but those values defined in the **where** block will be injected at appropriate places, as defined in the method. In our case, we modify the result we expect from the test along with the variable that we set before processing.

Now, the `@Unroll` annotation. It's an optional annotation you can add to tests that contain the **where** block. What it does is - once the test is launched - it *unrolls* the single test method into multiple test cases, substituting our *moving parts* in the test name. It makes it easier to analyze when launching the tests.

Without `@Unroll` the output window would show us a single entry, even though there were actually two separate tests (although with the same setup):

> should resolve shorthand ternary expression given variable

With the annotation, we will have as many tests as there are cases in the where block (two, in this example):

> should resolve shorthand ternary expression given variable: true

> should resolve shorthand ternary expression given variable: false

The **rest of the code** is pretty straightforward: we define a script variable, which is our input, then provide Wordplay with a variable and make it process our input, and finally - validate whether the produced output is what we expect. This test is ran two times, once with setting the `weather_sunny` variable to true, and once with setting it to false. The result differs based on the variable.

---
## Execution

Before we'll be able to run the tests, we need to provide the required (empty) functions to our `Wordplay` interface and `WordplayImpl` implementation:

```java
public interface Wordplay {
    String process(String input);
    void reset();
    void setVariable(String var, boolean value);
    void setVariable(String var, String value);
}
```

```java
public class WordplayImpl implements Wordplay {

    @Override
    public String process(String input) {
        return null;
    }

    @Override
    public void reset() {
        
    }

    @Override
    public void setVariable(String var, boolean value) {
        
    }

    @Override
    public void setVariable(String var, String value) {

    }
}
```

If we now run the test (I do it from the IntelliJ IDE), what we will see is this:

![Wordplay]({{site.baseurl}}/public/images/wordplay_testlaunched_1.png)
*Remember kids: black, red and exclamation marks = bad*

We have two tests displayed even though we wrote just one function - that's due to the `@Unroll` annotation along with the **where** block.

As we can see, both of them failed, which is probably because we have no implementation :)

What is very nice of **Spock** is that it gives us a human-readable explanation of why the condition was not satisfied. Looking at our example, we can see that our *output* was `null`, our *result* was as defined in the test and so the `equals` method of the two had to return *false*. Everything clear.

Thanks to this clear explanation and string-based test names, **if we are thorough with naming our tests and defining our conditions** then the suit of tests we create for the whole project will always **tell us exactly what is wrong** if we break something while implementing new functionality.

As far as I understand it, **this is the ultimate benefit of going through the pain of creating tests and sticking to the TDD process**.

---
## You shall... pass!

Once we've created our test and ensured it fails, according to [TDD](https://en.wikipedia.org/wiki/Test-driven_development), it's now time to write code that will make it pass.

Note: we're not writing code that's perfect, or even good. We're writing code **that will make the test pass**.

```java
public class WordplayImpl implements Wordplay {

    private Map<String, Boolean> booleanVariablesMap = new HashMap<>();

    @Override
    public String process(String input) {
        int openingBracketIndex = input.indexOf('{');
        int closingBracketIndex = input.indexOf('}');

        if (openingBracketIndex == -1 || closingBracketIndex == -1)
            return null;

        String expression = input.substring(openingBracketIndex+1, closingBracketIndex);

        if (!expression.contains("?") && !expression.contains("|"))
            return null;

        String variable = expression.split("\\?")[0].trim();
        String rest = expression.split("\\?")[1].substring(1);
        String[] split = rest.split("\\s\\|\\s");
        String first = split[0];
        String second = split[1];

        String result = booleanVariablesMap.get(variable) != null &&
                booleanVariablesMap.get(variable) == true ? first : second;

        return input.substring(0, openingBracketIndex) 
                + result 
                + input.substring(closingBracketIndex+1);
    }

    @Override
    public void reset() {
        booleanVariablesMap.clear();
    }

    @Override
    public void setVariable(String var, boolean value) {
        booleanVariablesMap.put(var, value);
    }

    @Override
    public void setVariable(String var, String value) {

    }
}
```

Yes, this code is bad. Yes, it only covers one specific scenario and will fail if we have nested expressions or other weird stuff. But guess what - **it also makes the test pass**.

![Wordplay tests pass]({{site.baseurl}}/public/images/wordplay_tests_pass.png)
*Dark color scheme when it's bad and changing to light when it's fine - talk about subliminal messages*

Which, according to TDD, is all we want at this stage.

What comes next is the **refactoring stage**. This is the stage where we take care of code readability and maintainability, where we move it into classes and packages that are logical from the point of view of the whole, not just from the point of view of making a single test pass. All of that while constantly re-running the test to ensure it still passes.

I'm not going to show you that stage, because, frankly, I don't know how to implement *Wordplay* in a sensible manner yet :)

Once we do our refactoring and the test still passes - we move on to the next test and **repeat**.

---
## Conclusions

I hope I've managed to convince you that **TDD is a useful tool** to have in your arsenal.

If you expect your code to be difficult to maintain in the future, do your future self a favour and spend some time making those tests. If some old functionality breaks when adding new features, your future self **will know what, where and why** - assuming you **name your tests thoroughly and define clear test conditions**.

There are many testing frameworks out there, such as the mentioned **JUnit**, but I find **Spock** quite a powerful tool, worthy of wielding. If you're scared of **Groovy** - don't be. It's very similar to **Java** and the stuff you need to know to work with **Spock** is quite basic.

Good luck, and remember to have fun :)

Oh, and if you're curious to know how's the progress on Wordplay - you can check out its [github page](https://github.com/rskupnik/wordplay).