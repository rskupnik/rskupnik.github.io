---
layout: post
title: Dagger - dependency injection with no runtime overhead
---

---

If you are like me and you worked in Java web dev, then you might have had the chance to work with **Spring** and it's *dependency injection*. It makes your code a lot more clean and easier to follow. Wouldn't it be great to use dependency injection in your **pet project** without worrying about it being slow due to reflection or not working on some environments?

**Dependency injection** is one form of *inversion of control*. The basic principle is that instead of managing dependencies between components in your code by yourself, you use a single container to resolve those for you and inject the required dependencies where you want them. You, as a programmer, only have to define how a specific dependency is to be satisfied (create a new object each time, or maybe use a single object for each case, etc.) and then simply provide variables that will hold those dependencies where you need them, add some required annotations - and you're done, the DI library will *inject* the dependencies into those variables as instructed.

Do note that by *dependencies* I actually mean classes, components in your code - **not** what you define as Maven/Gradle dependencies - those are a different concept. Hopefully it will become clear once I show you some code.

There are several options available when it comes to dependency injection. Here's a few:
* Google Guice
* Spring DI
* Dagger

So, what's the difference between those? The difference, among others, is in how they operate - Guice and Spring use **reflection** to resolve your dependencies during **runtime**, while Dagger plugs itself into **compilation phase** and generates **static code** that will resolve those dependencies.

One could say it's a classic space-time tradeoff - **runtime** resolution is slower, but doesn't generate any code, while **compile-time** resolution is faster in the runtime but adds some "clutter".

The choice, in my opinion, should be based on two things: **research** and **context**. You should first learn about what the different libraries have to offer and consider that in the context of what you want to achieve.

For example, if you're making a library that is to be used by other people, or you're making an app that will run on desktop and on Android - compile-time dependency injection might be better, because runtime reflection might be very slow on Android; or someone who wants to use your library might not like that it introduces unnecessary (from his point of view) runtime overhead due to reflection.

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

The important part is the **no-args constructor** annotated with `@Inject`. According to [dagger's documentation](https://google.github.io/dagger//users-guide.html):

> Use @Inject to annotate the constructor that Dagger should use to create instances of a class. (...) If your class has @Inject-annotated fields but no @Inject-annotated constructor, Dagger will inject those fields if requested, but will not create new instances. Add a no-argument constructor with the @Inject annotation to indicate that Dagger may create instances as well.

Long story short - if we want Dagger to instantiate our class, we need to **tell it which constructor to use** - and we do that with a `@Inject` annotation. Quite simple.

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

Again, nothing fancy - just a constructor annotated with `@Inject`. Let's now use those two components:

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

Now, here's where we see the benefit of *dependency injection*. In our `Computer` class we simply provide both `Keyboard` and `Screen` as `@Inject`-annotated fields (note that they cannot be private in case of Dagger) - **and that's it**. When we finish configuration, our `Computer` will just work, we don't have to take care of providing the `Keyboard` and `Screen` classes manually. Can you imagine how huge of an advantage it is in the case of large, real-world applications?

## Configuration

Alright, all the code is there but to make it work we need to provide a few more things.

First of all, we have to have some code that will **trigger** the whole mechanism. Once triggered, Dagger will traverse through all our annotated objects and do the whole injection magic.

While we're at it, there's an **important rule** you need to know - when you're using *dependency injection* you have to remember to **not** instantiate managed objects by yourself. That means you should not do `new Keyboard()`, for example. If you do that, Dagger has no way of knowing that such an object was just created and that it should be managed - such an instance of `Keyboard` will be invisible to our *dependency injection* framework. You have to **trigger** Dagger's mechanism so that it can discover and initialize those classes by itself - that way Dagger is aware of them and can manage them.

So how do we do that triggering part? We need to create an interface with a method that returns the object we want to be the **starting point** of the whole mechanism:

```java
@Component
public interface ComputerInjector {
    Computer computer();
}
```

In our case, the starting point is the `Computer` class. Why? Because it's the one that's not injected anywhere else and holds references to all other components. Dagger will start from `Computer`, go through all the dependencies it declares (all fields annotated with `@Inject`) and will **satisfy those dependencies** - in our example, Dagger will create both `Keyboard` and `Screen` using the constructors we told it to use and assign them to the variables.

Once we have the `ComputerInjector` we can move on to the **actual triggering** part:

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

So, here's how the whole process looks like:
1. We use the instance of our `@Component`-annotated interface that Dagger generated to **trigger** the mechanism. We do that by invoking a function that returns one of our objects that will serve as a starting point - `Computer` in this case.
2. Dagger analyzes the starting point class and attempts to satisfy its dependencies. This is a cascading process.
3. Once Dagger is finished, our classes should have all of their dependencies satisfied and they can be used as if the `@Inject`-annotated fields are present.

If you compile and run the application now, it should work as expected - you should be able to provide input (as per `Keyboard` implementation) and it will be printed to the console by our `Screen` class.

It is possible that it won't work at first attempt - that's because the generated code is not yet present. In such a case, simply try and run it again, or/and run `mvn clean install` beforehand.

So there you have it. We were able to **create a few independent components** and **wire them up together** using a few simple annotations and some configuration code. Notice that the configuration code is a one-time thing (with maybe some tinkering later on, if required) - once it's done, you can simply create any components, annotate them properly and use them from anywhere by simply `@Inject`-ing them into fields or constructors.

There's one other thing I'd like to show you, though.

## Providers

What if we use a third party library that provides us with some interface and an implementation? Since we only get a compiled class file, we can't just edit it and insert an `@Inject`-annotated constructor. So how do we make Dagger work with it? The answer is **providers**.

Let's write a bit of code to serve as an example. Suppose we get a requirement to not only print the input gathered by our `Keyboard` on the `Screen` but also send it to a `Printer` which is provided by a third party as a compiled class with an interface.

```java
public interface Printer {
    void print(String s);
}
```

```java
public class PrinterImpl implements Printer {

    public void print(String s) {
        System.out.println("~~~ " + s + " ~~~");
    }
}
```

Remember, we don't have access to the `PrinterImpl` class. We have to work with what we have here.

In order to integrate this `Printer` with Dagger, we have to use a **Provider** - and to specify one, we have to use a **Module**. Here's how it looks like:

```java
@Module
public class ProvidersModule {

    @Provides
    Printer printer() {
        return new PrinterImpl();
    }
}
```

The `Module` contains methods annotated with `@Provides` annotation with a return value of the interface we want to work with. The body of the method does the instantiation part and returns an actual instance. The name of the method doesn't matter. This way we can integrate third party components and make them work with our *dependency injection* framework.

The only additional thing we need to do is inform our `ComputerInjector` about `ProvidersModule`:

```java
@Component(modules = ProvidersModule.class)
public interface ComputerInjector {
    Computer computer();
}
```

And that's it! We can now simply add it to our code as we would with our own components:

```java
public class Computer {

    @Inject Keyboard keyboard;
    @Inject Screen screen;
    @Inject Printer printer;

    @Inject
    public Computer() {

    }

    public void use() {
        String input = keyboard.use();
        screen.print(input);
        printer.print(input);
    }
}
```

Running the code should run without any problems and work as intended:

```
Hello World!
=== Hello World! ===
~~~ Hello World! ~~~
```

---
## Conclusions

There you have it - a dependency injection library that works during the compilation phase and does not really on slow and resource-heavy reflection.

**Dependency injection is a powerful technique** and makes a developer's life a whole lot easier by removing a ton of boilerplate code. Being able to use it not only in web development, but also in small projects and libraries is great. I believe that some additional time spent on setting up this mechanism is well worth it, especially when compared to how much **time and headaches dependency injection spares**.

I've always wanted to be able to use Spring-like dependency injection in my pet projects, such as games and libraries, but **relying on reflection was a big blocker** - in case of games, because I do not know if the environment that runs the game provides a fast enough reflection (like Android); and in case of libraries - because the potential user might not want to use a library that heavily relies on reflection and might be slow.