---
layout: post
title: Dependency injection with no runtime overhead - Dagger 2
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

Explanations out of the way, let's now see how to make a basic library with Dagger 2.

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

We need to provide two things to make Dagger work - the dependency itself and an annotation processor that plugs into compile phase and generates the necessary boilerplate code.