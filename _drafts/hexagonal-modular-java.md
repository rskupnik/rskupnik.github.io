---
layout: post
title: Achieving a framework-independent zen with the power of interfaces and hexagonal architecture
---

Have you ever wondered what would happen if Spring was to suddenly pop out of existence? How easy would it be to migrate your web application to a different framework? Would it be possible at all? Don't worry, this is not one of those posts where I tell you that Spring is the root of all evil and you should try the fancy-new-alternative framework instead! What I do want to tell you, though, is that **strong dependency on external components is dangerous** and often hinders your project's elasticity and capability to change - those two aspects are very close to AGILE and we don't want to risk being called UNAGILE, don't we?

"Easier said than done", you might say, as web frameworks nowadays can be very intrusive. Contrary to libraries, they often enforce their structure, vision or conventions on us, making it necessary to adhere to those if we want to use the framework. Some of them introduce their own CLI tools to setup the aforementioned structure and conventions for you. Some others got so robust and compilcated they need a module to make it a sane experience to start working with them (looking at you, Spring Boot). Is it at all possible to isolate your logic and domain code in this situation?

My answer to that is - yes, it is possible - although not always easy. I'll try to show you how to isolate the logic and domain code of your application into a no-dependency module that can then be turned into a web application using whatever framework you choose, integrating seemlessly with it's dependency injection mechanism. Such isolated core can also be easily tested with the whole web layer completely missing. Sounds enticing?

Of course, the real world is not sunshine and rainbows and complexity tends to sneak in uninvited and often unnoticed. Being able to swap your domain logic from one framework to another without any issues is probably nigh impossible, but hexagonal architecture at least allows us to consider that as a realistic option, instead of a 2-year-long huge-risk endeavour that we use to scare our product owners with.

Here's what we will achieve:

(TODO: An image of the hexagonal core)

---

## Know thy tools

There are a few concepts and tools being used to achieve our goal. We take a bit from DDD to isolate our domain, use the hexagonal approach to allow our core application of being independent of the input provider (an HTTP server, in this case) and Java 9 modules to make it a bit more fun, but we can very well have done it with Java 8. Let's make sure we have a common understanding of those concepts.

### Hexagonal architecture

Hexagonal architecture is a huge topic, so I'll only mention the few key aspects here. If you want to know more, Chris Fidao has created a great article about it - you can find it [here](https://fideloper.com/hexagonal-architecture).

Hexagonal architecture is about structuring our application in layers, where each layer sits on top of the previous one and introduces potential third-party dependencies it might need to fulfill it's job - the important part here is that each layer only brings in what it really needs. In other words, the dependencies are **moving in**. For example, the domain logic of our application can do perfectly fine without knowing the notion of an "HTTP Request", so our *domain* and *application* layers don't need any web-related dependencies. But, once we arrive at a point when we want the domain logic to be triggerbale via HTTP, we need to introduce a dependency - in our case, that will happen in the *framework* layer.

"Why a hexagon", you might ask. That's just a visual way of showing that our application exposes *Ports* as a means of telling the higher layers how it should be used. Using the powerful notion of *interfaces* we achieve per-layer independence.

---

## Let's get dirty

First of all, we'll create a Maven project to hold two modules, each one representing a hexagonal layer: *domain* and *application*.

The *domain* layer will hold classes which represent the model of our application, while the *application* layer will hold some basic business logic that manages those classes.

(If we were to have a more advanced app, we'd probably want to have more and better specified layers. See the already-mentioned [Chris Fidao's post](https://fideloper.com/hexagonal-architecture) for more details.)

You can view the code for this part here: [https://github.com/rskupnik/pet-clinic-modular](https://github.com/rskupnik/pet-clinic-modular)

It's a basic multimodule maven layout, nothing fancy. Make sure you reference your modules in your root-level `pom.xml`:

```xml
<modules>
    <module>com.github.rskupnik.petclinicmodular.domain</module>
    <module>com.github.rskupnik.petclinicmodular.application</module>
</modules>
```

### Lair of the Domain

We will model a pet clinic, which has two domain objects - a *Customer* and a *Pet*. A *Customer* can have many *Pets*, and a particular *Pet* can only belong to one *Customer*. Basic one-to-many relationship. Our app will let us register a *Customer* with a list of *Pets*, list all the *Customers* and their *Pets*, list a single *Customer* and list all *Pets*. Again, just basic CRUD stuff.

It's not really important what the app does, it's just to have a concrete example to apply the idea to.

Our domain has a `pom.xml` with zero dependencies and the two classes, *Customer* and *Pet*:

```java
public class Customer {

    private Long id;
    private String firstName, lastName;
    private List<Pet> pets;

    public Customer() {

    }

    public Customer(String firstName, String lastName, List<Pet> pets) {
        this.firstName = firstName;
        this.lastName = lastName;
        this.pets = pets;
    }

    // GETTERS & SETTER HERE
}
```

```java
public class Pet {

    private Long id;
    private String name;
    private Customer owner;

    public Pet() {

    }

    public Pet(String name) {
        this.name = name;
    }

    // GETTERS & SETTER HERE
)
```

Since we want to use Java 9 modules for fun, there's an additional `module-info.java` file, in which we define the *domain* module and expose the *domain.customer* and *domain.pet* packages.

```java
module com.github.rskupnik.petclinicmodular.domain {
    exports com.github.rskupnik.petclinicmodular.domain.customer;
    exports com.github.rskupnik.petclinicmodular.domain.pet;
}
```

### Application layer

This is the place where we implement business logic. It is also the place where we define our first interfaces as a means of telling the at-this-point-unknown higher layers of how this layer is meant to be used.

In our case, we define `Repository` and `Service` interfaces for both *Pet* and *Customer*. Those interfaces define what actions can be performed on those entities.

Important note: in a robust application, we might want to introduce CQRS and a fancy `CommandBus` at this point, but I've skipped that for simplicity's sake.

Before we can make this layer work, we need to add a maven dependency on the layer below it - *domain*.

```xml
<dependency>
    <groupId>com.github.rskupnik.petclinicmodular</groupId>
    <artifactId>domain</artifactId>
    <version>1.0-SNAPSHOT</version>
    <scope>compile</scope>
</dependency>
```

Now let's have a look at what we can do with the *Customer*.

```java
public interface CustomerRepository {

    List<Customer> getAll();

    Customer get(Long id);

    void add(Customer customer);

    static CustomerRepository defaultRepository() {
        return new DefaultCustomerRepository();
    }
}
```

```java
public interface CustomerService {

    Customer get(long id);

    List<Customer> getAll();

    void add(Customer customer);

    static CustomerService defaultService(CustomerRepository repository, PetService petService) {
        return new DefaultCustomerService(repository, petService);
    }
}
```

Everything here is pretty straightforward, except maybe the `defaultX()` static methods. What are these for?

From the point of view of the *application* layer, we define the `CustomerService` interface that tells whatever will be using it how it wishes to be used and what it allows for. Right, but where should we put the business logic then? My take on this is to introduce a `DefaultCustomerService`, put the business logic in there and make sure it's easy for whoever is looking into satisifying the `CustomerService` dependency to know there is a default implementation available - hence the static constructor method in the interface.

Our default implementation uses a basic in-memory solution to store the data.

If you look into `DefaultCustomerService`'s code, you can see it has two dependencies:

```java
public DefaultCustomerService(CustomerRepository customerRepository, PetService petService) {
    this.customerRepository = customerRepository;
    this.petService = petService;
}
```

How do we satisfy those dependencies, though? Well, that's not a concern of this layer - this layer only needs to define the business logic that manipulates the domain objects. It can selflessly define the dependencies it needs and expect the higher layer to satisfy them, most probably using some sort of dependency injection mechanism.

Finally, the Java 9 `module-info.java`, which clearly expresses that we depend on the *domain* layer and export some stuff.

```java
module com.github.rskupnik.petclinicmodular.service {
    requires com.github.rskupnik.petclinicmodular.domain;

    exports com.github.rskupnik.petclinicmodular.application.customer.service;
    exports com.github.rskupnik.petclinicmodular.application.customer.repository.api;
    exports com.github.rskupnik.petclinicmodular.application.pet.service;
}
```

That's it, we now have a very basic application with no external dependencies. In the next step, we'll try to apply Spring to it and turn it into a web app.

---

## Springification

This part of the code can be viewed here: [https://github.com/rskupnik/pet-clinic-modular-spring](https://github.com/rskupnik/pet-clinic-modular-spring).

I've created a basic Spring Boot app using [Spring Initializr](https://start.spring.io/) with only the *Web* dependency.

Once we have the basic project skeleton, we add our core application as a dependency.

```xml
<dependency>
    <groupId>com.github.rskupnik.petclinicmodular</groupId>
    <artifactId>application</artifactId>
    <version>1.0-SNAPSHOT</version>
</dependency>
```

Then we introduce some DTO classes, here's the *CustomerDto* example:

```java
public class CustomerDto {

    private String firstName, lastName;
    private List<PetDto> pets;

    public CustomerDto() {

    }

    private CustomerDto(String firstName, String lastName, List<PetDto> pets) {
        this.firstName = firstName;
        this.lastName = lastName;
        this.pets = pets;
    }

    // GETTERS & SETTERS HERE

    public static CustomerDto fromDomain(Customer customer) {
        return new CustomerDto(customer.getFirstName(), customer.getLastName(), customer.getPets() != null
         ? customer.getPets().stream().map(PetDto::fromDomain).collect(Collectors.toList()) : null);
    }

    public Customer toDomain() {
        return new Customer(firstName, lastName, pets != null ? pets.stream()
        .map(PetDto::toDomain).collect(Collectors.toList()) : null);
    }
}
```

The static mapper functions should be moved to dedicated *Mapper* classes in a real application.

And a basic controller:

```java
@RestController
@RequestMapping("/customers")
public class CustomerController {

    private final CustomerService customerService;

    @Autowired
    public CustomerController(CustomerService customerService) {
        this.customerService = customerService;
    }

    @RequestMapping(method = RequestMethod.GET, value = "/{id}", produces = "application/json")
    public CustomerDto get(@PathVariable Long id) {
        return CustomerDto.fromDomain(customerService.get(id));
    }

    @RequestMapping(method = RequestMethod.GET, produces = "application/json")
    public List<CustomerDto> getAll() {
        return customerService.getAll().stream().map(CustomerDto::fromDomain).collect(Collectors.toList());
    }

    @RequestMapping(method = RequestMethod.POST, consumes = "application/json")
    public void add(@RequestBody CustomerDto customer) {
        customerService.add(customer.toDomain());
    }
}
```

All fine and dandy, but remember that the *application* layer slefishly declared the dependencies, expecting the *framework* layer to satisfy them? We can use Spring's dependency injection to achieve just that:

```java
@Configuration
public class ImplementationConfig {

    @Bean
    public PetRepository petRepository() {
        return PetRepository.defaultRepository();
    }

    @Bean
    public PetService petService(PetRepository petRepository) {
        return PetService.defaultService(petRepository);
    }

    @Bean
    public CustomerRepository customerRepository() {
        return CustomerRepository.defaultRepository();
    }

    @Bean
    public CustomerService customerService(CustomerRepository customerRepository, PetService petService) {
        return CustomerService.defaultService(customerRepository, petService);
    }
}
```

There we go. Dependencies satisfied using the default implementations. All that remains is to add the DTO and controller for *Pet*, and our app is ready to work as a web app.

## Switching In-Memory to Spring-Data

What if we wanted to save the domain data into an actual database instead of keeping it in-memory by using the default implementation?

We can add support for spring-data, but it's not as straightforward. The main problem is that the `Repository` interface our *application* layer defined is incompatible with Spring's convention of creating interfaces that extend the `CrudRepository` which Spring then takes and creates implementation for, generating conventional method names.

Luckily, there is a way to make incompatible interfaces talk to each other and it's called the [Adapter Design Pattern](https://sourcemaking.com/design_patterns/adapter).

As such, without further ado - let's create out adapter classes. By the way, you can view code for this section in the same repository ([https://github.com/rskupnik/pet-clinic-modular-spring](https://github.com/rskupnik/pet-clinic-modular-spring)), just switch the branch to `spring-data`.

First of all, we need a Spring-Data-compliant interface to adapt to:

```java
@Repository
public interface CustomerRepositoryJPA extends CrudRepository<Customer, Long> {
}
```

And the adapter itself:

```java
@Repository
public class CustomerRepositoryAdapter implements CustomerRepository {

    private final CustomerRepositoryJPA repository;

    @Autowired
    public CustomerRepositoryAdapter(CustomerRepositoryJPA repository) {
        this.repository = repository;
    }

    @Override
    public List<Customer> getAll() {
        final List<Customer> output = new ArrayList<>();
        repository.findAll().forEach(output::add);
        return output;
    }

    @Override
    public Customer get(Long id) {
        return repository.findById(id).orElse(null);
    }

    @Override
    public void add(Customer customer) {
        repository.save(customer);
    }
}
```

Done. We can use our `CustomerRepositoryAdapter` as a `CustomerRepository` (interface introduced by `application` layer) and it will transparently route to the `CustomerRepositoryJPA` underneath.

We can now simply swap the bean implementation of the `CustomerRepository` interface in the config class:

```java
@Bean
public CustomerRepository customerRepository(CustomerRepositoryJPA jpaRepo) {
    return new CustomerRepositoryAdapter(jpaRepo);
}
```

The application will work as it did before, except now it will use Spring-Data to save to an actual database.