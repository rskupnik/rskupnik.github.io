---
layout: post
title: Dagger - dependency injection with no runtime overhead
---

---

If you are like me and you worked in Java web dev, then you might have had the chance to work with **Spring** and it's *dependency injection*. It makes your code alot more clean and easier to follow. Wouldn't it be great to use dependency injection in your **pet project**?

Before we answer that question - I assume you know what *dependency injection* is. In case you don't, a short and basic explanation. *Dependency injection* is one form of *inversion of control*. The basic principle is that instead of managing dependencies between components in your code by yourself, you use a single container to resolve those for you and inject the required dependencies where you want them. You, as a programmer, only have to define how a specific dependency is to be satisfied (create a new object each time, or maybe use a single object for each case, etc.) and then simply provide variables that will hold those dependencies where you need them, add some required annotations and you're done, the DI library will *inject* the dependencies into those variables as instructed.

Do note that by *dependencies* we actually mean classes, components in your code - **not** what you define as Maven/Gradle dependencies - those are a different concept.

There are several options available and here's a few:
* Google Guice
* Spring DI
* Dagger

So, what's the difference between those? The difference is in how they operate - Guice and Spring use **reflection** to resolve your dependencies during **runtime**, while Dagger plugs itself into **compilation phase** and generates **static code** that will resolve those dependencies.

One could say it's a classic space-time tradeoff - **runtime** resolution is slower, but doesn't generate any code, while **compile-time** resolution is faster in the runtime but adds some "clutter".

The choice, in my opinion, should be based on two things: research and context. You should first learn about what the different libraries have to offer and consider that in the context of what you want to achieve.

For example, if you're making a library that is to be used by other people, or you're making an app that will run on desktop and on Android - compile-time dependency injection might be better, because runtime reflection might be very slow on Android or someone who wants to use your library might not like that it introduces unnecessary (from his point of view) runtime overhead.

Explanations out of the way, let's now see how to make a basic library with Dagger 2. We'll create something very simple - a basic computer emulator.

---
## Implementation

I'll be using Maven in this example, so let's start with our `pom.xml` file:

```xml
<project xmlns="http://maven.apache.org/POM/4.0.0" 
xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 
  http://maven.apache.org/maven-v4_0_0.xsd">

  <modelVersion>4.0.0</modelVersion>
  <groupId>com.github.rskupnik</groupId>
  <artifactId>dagger-example</artifactId>
  <packaging>jar</packaging>
  <version>1.0</version>
  <name>dagger-example</name>
  
  <dependencies>
    <dependency>
        <groupId>com.google.dagger</groupId>
        <artifactId>dagger</artifactId>
        <version>2.11</version>
    </dependency>
    <dependency>
      <groupId>com.google.dagger</groupId>
      <artifactId>dagger-compiler</artifactId>
      <version>2.11</version>
      <scope>provided</scope>
    </dependency>
  </dependencies>
  
  <build>
    <plugins>
      <plugin>
      <groupId>org.apache.maven.plugins</groupId>
      <artifactId>maven-compiler-plugin</artifactId>
      <version>3.6.1</version>
      <configuration>
        <annotationProcessorPaths>
          <path>
            <groupId>com.google.dagger</groupId>
            <artifactId>dagger-compiler</artifactId>
            <version>2.11</version>
          </path>
        </annotationProcessorPaths>
      </configuration>
    </plugin>
    </plugins>
  </build>
  
</project>
```

We need to provide two things to make Dagger work - the dependency itself and an annotation processor that plugs into compile phase and generates the necessary boilerplate code. This is required here because Dagger is a **compile-time** dependency injection - as mentioned earlier, it generates some code to satisfy the dependencies.

Let's now move on to some Java code. Our application will be very simple - we'll have a `Computer` that uses a `Keyboard` and a `Screen` to read some data from the user and print it. It's **very** basic and that's intended - it'll let us focus on the actual dependency injection part.

Here's how our `Keyboard` class will look like:

```java
public class Keyboard {

    private Scanner scanner = new Scanner(System.in);

    @Inject
    public Keyboard() {

    }

    public String use() {
        return scanner.nextLine();
    }
}
```

The important part is the **no-args constructor** annotated with `@Inject`. According to [dagger's documentation]():

> Use @Inject to annotate the constructor that Dagger should use to create instances of a class. (...) If your class has @Inject-annotated fields but no @Inject-annotated constructor, Dagger will inject those fields if requested, but will not create new instances. Add a no-argument constructor with the @Inject annotation to indicate that Dagger may create instances as well.

Long story short - if we want Dagger to instantiate our class, we need to tell it which constructor to use - and we do that with a `@Inject` annotation. Quite simple.

We have a `Keyboard`, let's now create a `Screen`:

```java
public class Screen {

    @Inject
    public Screen() {

    }

    public void print(String s) {
        System.out.println("=== " + s + " ===");
    }
}
```

Again, nothing fancy - just a constructor annotated with `@Inject`.

```java
public class Computer {

    @Inject Keyboard keyboard;
    @Inject Screen screen;

    @Inject
    public Computer() {

    }

    public void use() {
        String input = keyboard.use();
        screen.print(input);
    }
}
```

Now here's where we see the benefit of *dependency injection*. In our `Computer` class we simply provide both `Keyboard` and `Screen` as `@Inject`-annotated fields (note that they cannot be private in case of Dagger) - **and that's it**. When we finish configuration our `Computer` will just work, we don't have to take care of providing the `Keyboard` and `Screen` classes manually. Can you imagine how huge of an advantage it is in the case of large, real-world applications?

## Configuration

Alright, all the code is there but to make it work we need to provide a few more things.

First of all, we have to have some code that will **trigger** the whole mechanism. Once triggered, Dagger will traverse through all our annotated objects and do the whole injection magic.

While we're at it, there's an **important rule** you need to know - when you're using *dependency injection* you have to remember to **not** instantiate managed objects by yourself. In our example that means you should not do `new Keyboard()`, for example. If you do that, Dagger has no way of knowing that such an object was just created and that it should manage it - such an instance of `Keyboard` will be invisible to our *dependency injection* framework. You have to **trigger** Dagger's mechanism so that it can discover and initialize those classes by itself - that way Dagger is aware of them and can manage them.

So how do we do that triggering part? We need to create an interface with a method that returns the object we want to be the starting point of the whole mechanism:

```java
@Component
public interface ComputerInjector {
    Computer computer();
}
```

In our case, the starting point is the `Computer` class. Why? Because it's the one that's not injected anywhere else. Dagger will start from `Computer`, it go through all the dependencies it needs (all fields annotated with `@Inject`) and will **satisfy those dependencies** - in our example, Dagger will create both `Keyboard` and `Screen` using the constructors we told it to use.

Once we have the `ComputerInjector` we need move on to the **actual triggering** part:

```java
public class Main {

    public static void main(String[] args) throws Exception {
        ComputerInjector injector = DaggerComputerInjector.create();
        injector.computer().use();
    }
}
```

This is the entry point to our program. Notice the `DaggerComputerInjector`? Dagger's documentation specifies that it will create an instance of our `@Component`-annotated interface by appending `Dagger` to it.

Because this class is not present at first your IDE will probably highlight it as an error. That's ok, the error should go away after first compilation, since Dagger will generate the class then.

So, the here's how the whole process looks like:
1. We use the instance of our `@Component`-annotated interface that Dagger generated to **trigger** the mechanism. We do that by invoking a function that returns one of our objects that will serve as a starting point - `Computer` in this case.
2. Dagger analyzes the starting point class and attempts to satisfy its dependencies. This is a cascading process.
3. Once Dagger is finished, our classes should have all of their dependencies filled and they can be used as if the `@Inject`-annotated fields are present.