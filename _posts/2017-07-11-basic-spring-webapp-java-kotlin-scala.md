---
layout: post
title: Basic Spring web application in Java, Kotlin and Scala - comparison
---

I've been wondering how hard would it be to implement a basic **Spring Boot** app in alternative JVM languages, such as **Scala** and **Kotlin**, so I've decided to give it a try :)

The source code is available at [https://github.com/rskupnik/pet-clinic-jvm](https://github.com/rskupnik/pet-clinic-jvm)

The app is very basic, as it only consists of the following elements:
* Two database entities
* Two repositories
* Two controllers
* Six endpoints
* A dummy, static `index` page
* `Vue.js` thrown in for the lulz

I'll do a code comparison of the layers in three languages:
* Java
* Kotlin
* Scala

---
## Entities

We have two entities here: `Customer` and `Pet`.

## Java
```java
@Entity
public class Customer {

    @Id
    @GeneratedValue
    private Long id;
    private String firstName, lastName;

    @JsonIgnore
    @OneToMany(mappedBy = "owner")
    private List<Pet> pets;

    protected Customer() {

    }

    public Customer(String firstName, String lastName) {
        this.firstName = firstName;
        this.lastName = lastName;
    }

    // A whole lot of getters and setters here...
    // Ommited for the sake of brevity

    @Override
    public String toString() {
        return firstName+" "+lastName;
    }
}
```

```java
@Entity
public class Pet {

    @Id
    @GeneratedValue
    private Long id;
    private String name;

    @ManyToOne
    @JoinColumn(name = "ownerId", nullable = false)
    private Customer owner;

    protected Pet() {

    }

    public Pet(String name) {
        this.name = name;
    }

    // A whole lot of getters and setters here...
    // Ommited for the sake of brevity

    @Override
    public String toString() {
        return name;
    }
}
```

Not much to talk about here - obviously Java is verbose, so the code takes a lot of place even after stripping the getters and setters. Not much we can do about that, except maybe using **Lombok**, or a similar tool, that will generate the boilerplate for us.

## Kotlin

There are a few ways we can define an *entity class* in Kotlin, I've tried two. Both are working, although the latter is probably preferred, as the former simply tries to do the same as you would do in regular Java.

```kotlin
// Implementation using a data class (preferred)

@Entity
data class Customer(
        @Id @GeneratedValue
        var id: Long = 0,

        var firstName: String = "",
        var lastName: String = "",

        @JsonIgnore @OneToMany(mappedBy = "owner") 
        var pets: List<Pet>? = null
) {
    override fun toString(): String = "$firstName $lastName"
}
```

```kotlin
// Implementation using a regular class, mimicing regular Java

@Entity
class Pet {

    constructor() {

    }

    constructor(name: String) {
        this.name = name
    }

    @Id
    @GeneratedValue
    var id: Long = 0

    var name: String = ""

    @ManyToOne
    @JoinColumn(name = "ownerId", nullable = false)
    var owner: Customer? = null

    override fun toString(): String = "$name"
}
```

The *data class* implementation is much, much shorter and avoids a lot of boilerplate, although it might seem a bit *unintuitive* to Java programmers at first. Most of the verbosity here comes from the necessary annotations.

Note that *Entity classes* require a default constructor with no parameters - it's explicitly provided in the *regular class* case, while the *data class* provides it by defining **default values** for each of the parameters in a single constructor - including a default one with no parameters at all, which simply assignes defaults to each variable.

Having to explicitly define the `override` keyword is something I like as well, as it makes the code easier to read and less error prone.

Finally, *String interpolation* and the possibility to skip curly braces in one-liner functions shorten the code even further.

## Scala

```scala
// Implementation using a case class

@Entity
case class Customer(
       @(Id@field)
       @(GeneratedValue@field)
       @BeanProperty
       var id: Long,

       @BeanProperty
       var firstName: String,

       @BeanProperty
       var lastName: String,

       @(JsonIgnore@field)
       @(OneToMany@field)(mappedBy = "owner")
       @BeanProperty
       var pets: java.util.List[Pet]) {

  // Need to specify an empty constructor
  def this() {
    this(0, "", "", new util.ArrayList[Pet]())
  }

  override def toString: String = s"$firstName $lastName"

}
```

```scala
// Implementation using a regular class, mimicing regular Java

@Entity
class Pet {

  def this(name: String, owner: Customer) {
    this()
    this.name = name
    this.owner = owner
  }

  @Id
  @GeneratedValue(strategy = GenerationType.AUTO)
  @BeanProperty
  var id: Long = _

  @BeanProperty
  var name: String = _

  @ManyToOne
  @JoinColumn(name = "ownerId", nullable = false)
  @BeanProperty
  var owner: Customer = _

  override def toString: String = name 
}
```

In order to have getters and setters required by the underlying ORM, we need to use an additional annotation in Scala (`@BeanProperty`).

~~I tried to use a [case class](http://docs.scala-lang.org/tutorials/tour/case-classes.html) that should theoretically shorten the implementation quite a lot, but I could not get it working (perhaps my low Scala skills are to blame here).~~

The case class is actually possible, as explained to me by [Alexander Samsig](https://github.com/Asamsig) (thanks!). It requires the use of [scala.annotation.meta](http://www.scala-lang.org/api/2.12.0/scala/annotation/meta/index.html) in order to specify explicitly what the annotations should be attached to (in this example - the fields that will be generated).

Scala also provides *String interpolation*, allows ommision of curly braces in one-liners and requires explicit `override` keyword, which is on par with Kotlin.

---
## Repositories

## Java
```java
@Repository
public interface CustomerRepository extends CrudRepository<Customer, Long> {
    List<Customer> findByLastName(String lastName);
}
```

```java
@Repository
public interface PetRepository extends CrudRepository<Pet, Long> {

}
```

Note that the `findByLastName` function is not actually used anywhere, I've just defined it to provide an example.

## Kotlin
```kotlin
@Repository
interface CustomerRepository : CrudRepository<Customer, Long> {
    fun findByLastName(name: String): List<Customer>
}
```

```kotlin
@Repository
interface PetRepository : CrudRepository<Pet, Long>
```

Not much going on here, the code is basically the same. Kotlin version is a bit shorter because [the default modifier in Kotlin is public](https://kotlinlang.org/docs/reference/visibility-modifiers.html) and there's a `:` symbol instead of the `extends` keyword. Also, there's the possibility of ommiting curly braces if nothing is defined in the body.

## Scala
```scala
@Repository
trait CustomerRepository extends CrudRepository[Customer, java.lang.Long] {
  def findByLastName(lastName: String): List[Customer]
}
```

```scala
@Repository
trait PetRepository extends CrudRepository[Pet, java.lang.Long]
```

Scala uses [traits](http://docs.scala-lang.org/tutorials/tour/traits.html) instead of `interfaces`, but it's the same concept for the most part, or at least as far as our simple example requires.

For some reason there's the necessity to define the `Long` class explicitly as `java.lang.Long` to avoid compilation errors (or, again, I suck at Scala).

---
## Controllers

## Java

```java
@RestController
@RequestMapping("/customers")
public class CustomerController {

    private CustomerRepository customerRepository;

    @Autowired
    public CustomerController(CustomerRepository customerRepository) {
        this.customerRepository = customerRepository;
    }

    @GetMapping(value = "/{id}", produces = "application/json")
    public Customer getCustomer(@PathVariable("id") Long id) {
        return customerRepository.findOne(id);
    }

    @GetMapping(produces = "application/json")
    public List<Customer> getAllCustomers() {
        return (List<Customer>) customerRepository.findAll();
    }

    @GetMapping(value = "/formatted", produces = "application/json")
    public List<String> getAllCustomersFormatted() {
        return ((List<Customer>) customerRepository.findAll())
                .stream()
                .map(
                    customer -> customer.getFirstName()+" "+customer.getLastName()
                )
                .collect(Collectors.toList());
    }

    @PostMapping(produces = "application/json",
                 consumes = "application/json")
    public Customer addCustomer(@RequestBody Customer customer) {
        return customerRepository.save(customer);
    }
}
```

```java
@RestController
@RequestMapping("/pets")
public class PetController {

    @Autowired
    private PetRepository petRepository;

    @GetMapping(produces = "application/json")
    public List<Pet> getAllPets() {
        return (List<Pet>) petRepository.findAll();
    }

    @PostMapping(produces = "application/json",
                 consumes = "application/json")
    public Pet addPet(@RequestBody Pet pet) {
        return petRepository.save(pet);
    }
}
```

`CustomerController` is *constructor-injected*, while `PetController` is *field-injected* to provide an example for both - the same is done with the Kotlin and Scala versions.

Again, Java verbosity creeps in, although ~~much of it comes from *robust annotations*~~ (using `@Get/PostMapping` instead of `@RequestMapping` reduces annotation size). Note that Java 8 comes to the rescue, as the `getAllCustomersFormatted()` function would've been much more bloated in Java 7 due to the lack of lambda functions.

## Kotlin

```kotlin
@RestController
@RequestMapping("/customers")
class CustomerController(val customerRepository: CustomerRepository) {

    @GetMapping(value = "/{id}", produces = arrayOf("application/json"))
    fun getCustomer(@PathVariable("id") id: Long): Customer? = 
            customerRepository.findOne(id)

    @GetMapping(value = "/formatted", produces = arrayOf("application/json"))
    fun getAllCustomersFormatted() = 
            customerRepository.findAll().map { it.toString() }

    @GetMapping(produces = arrayOf("application/json"))
    fun getAllCustomers() = customerRepository.findAll()

    @PostMapping(produces = arrayOf("application/json"),
                 consumes = arrayOf("application/json"))
    fun addCustomer(@RequestBody customer: Customer): Customer? = 
            customerRepository.save(customer)
}
```

```kotlin
@RestController
@RequestMapping("/pets")
class PetController {

    // When using Autowired like this we need to make the variable lateinit
    @Autowired
    lateinit var petRepository: PetRepository

    @GetMapping(produces = arrayOf("application/json"))
    fun getAllPets() = petRepository.findAll()

    @PostMapping(produces = arrayOf("application/json"),
                 consumes = arrayOf("application/json"))
    fun addPet(@RequestBody pet: Pet): Pet? = petRepository.save(pet)
}
```

~~At first glance, this seems as verbose as Java, which is quite surprising, but we have to notice that the bulk of this verbosity comes from the *required annotations*. Strip away those and the body of the controller is just 4 lines.~~

~~This would, of course, present itself much less verbosely if I was to write the `@RequestMapping` annotations in a single line, but readability comes first when it comes to a blog post :)~~

Using `@Get/PostMapping` annotations instead allows us to skip at least the `method` parameter to decrease the annotation size. We could, theoretically, strip away the `produces` and `consumes` as well, but that would cause XML to also be a viable option - so those params are not redundant.

One annoying thing that needs to be pointed out is the necessity to use `arrayOf()` inside the annotations if they take more than one parameter (except for the default value). This is due to be [fixed in Kotlin 1.2](https://blog.jetbrains.com/kotlin/2017/06/early-access-program-for-kotlin-1-2-has-been-started/).

I like the constructor injection Kotlin provides (and we don't even need a `@Autowired` annotation for some ~~reason~~ [[this](https://www.reddit.com/r/java/comments/6mm3rc/a_basic_spring_boot_web_app_in_java_kotlin_and/dk2libq/) is the reason]) although it might look confusing if the class was larger and had much more dependencies to be injected - I'd say it's a opportunity for proper formatting in such a case.

*Type inference* also makes the functions quite shorter, as we don't need to specify the return type if it can be sensibly inferred; plus stripping away curly braces for one-line functions is a further decrease in number of lines.

## Scala

```scala
@RestController
@RequestMapping(Array("/customers"))
class CustomerController (
  private val customerRepository: CustomerRepository
) {

  @GetMapping(value = Array("/{id}"),
              produces = Array("application/json"))
  def getCustomer(@PathVariable("id") id: Long) = customerRepository.findOne(id)

  @GetMapping(produces = Array("application/json"))
  def getAllCustomers() = customerRepository.findAll()

  @GetMapping(value = Array("/formatted"),
              produces = Array("application/json"))
  def getAllCustomersFormatted() = {
    customerRepository
      .findAll()
      .asScala
      .map(_.toString())
      .asJava
  }

  @PostMapping(produces = Array("application/json"),
               consumes = Array("application/json"))
  def addCustomer(@RequestBody customer: Customer) = customerRepository.save(customer)
}
```

```scala
@RestController
@RequestMapping(Array("/pets"))
class PetController {

  @Autowired
  var petRepository: PetRepository = null

  @GetMapping(produces = Array("application/json"))
  def getAllPets = petRepository.findAll()

  @PostMapping(produces = Array("application/json"),
               consumes = Array("application/json"))
  def addPet(@RequestBody pet: Pet) = petRepository.save(pet)

}
```

Scala also requires an `Array` to be used when providing parameters, even for the default one.

~~The `getAllCustomersFormatted()` function, which is an atrocity, but I could not get the Java collections to work properly with Scala collections - so yeah, sorry for the eyesore~~ (scratch that, the code's been improved with some help from [Teemu Pöntelin](https://github.com/tehapo), thanks :) )

~~Notice having to include the `@Autowired()` in the constructor, which could've been skipped in Kotlin~~ (The `@Autowired` is actually not needed at all if you only have a single constructor, as explained [here](https://www.reddit.com/r/java/comments/6mm3rc/a_basic_spring_boot_web_app_in_java_kotlin_and/dk2libq/)).

As in Kotlin, Scala also allows for *type inference* and ommision of curly braces in one-liners.

---
## Summary

Although the application is very simple, it was enough for me to get a basic feeling of how it would be to create something bigger in each of the featured languages.

Given a choice between *Kotlin* and *Scala* I would rather go with **Kotlin**.

Why?

**First of all**, I feel like *Scala* is a second-class citizen in my IDE of choice (IntelliJ IDEA) while *Kotlin* is definitely a first-class citizen. This is quite obvious, given that the same company that created the IDE (Jetbrains) also created the *Kotlin* language itself - so of course they support it very well. Scala, on the other hand, is integrated via a plugin. The difference is quite visible, and - for me personally, at least - quite important.

**Second of all**, if I wanted to use *Scala* for web app development - I would go with [Play Framework](https://www.playframework.com/) - simply because it's designed with Scala in mind and the language will make things easier.

**Lastly**, although Scala and Kotlin provide mostly the same features when it comes to decreasing the amount of code written, Kotlin generates far less problems for beginner-to-intermediate language users in this case. That's probably due to Scala being more complicated (which is hardly a drawback, mind you) and having more features and thus it feels a bit like an overkill for the task at hand. Again, I'd advise using [Play Framework](https://www.playframework.com/) instead.

Those are **my personal reasons**, but **there are more**, more general ones.

I feel like *Scala* is more detached from *Java* than *Kotlin* is, since the latter is basically an extension that aims to fix the problems of the original, while the former aims to be a hybrid of imperative and functional programming. That being said, I believe *Scala* is much better used in other areas, such as **Big Data**, while *Kotlin* is excellent at what it's supposed to do - replace *Java* to relieve you of common headaches and provide tight interoperability.

Moreover, **Spring** itself seems to support *Kotlin* (or the other way around?) much more than it does *Scala*.

Finally, I believe *Kotlin* is easier to learn than *Scala*, from a Java programmer's point of view. That's mainly because it was designed as an improvement upon *Java* and doesn't put such a heavy emphasis on functional programming as *Scala* does. The interoperability with *Java* is also much tighter in *Kotlin*, which makes debugging problems easier.

Last but not least - I want to explicitly state that **I'm not bashing *Scala* in any way** (as some people seem to have that impression). I simply believe, that, **for me personally**, as far as **building a web app with Spring Boot in a JVM language that is not Java** is concerned - *Kotlin* is better at the job. The bold parts are important :) As mentioned earlier, *Scala* is excellent at other fields - such as the mentioned Big Data, for example - or in dedicated frameworks, but not necessarily at replacing *Java* in typical *Java* environments.