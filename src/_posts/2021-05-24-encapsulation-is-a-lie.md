---
layout: post
title: "Encapsulation is a Lie"
date: 2021-05-28 12:03:30 -0700
published: true
tags:
  - ruby
---

In this post I respond to another of Jason Swett's recent articles, [Don’t wrap instance variables in attr_reader unless necessary](https://www.codewithjason.com/dont-wrap-instance-variables-attr_reader-unless-necessary/). Jason, if you're reading this please know this blog isn't only about critiquing your writing, which I find insightful and thought-provoking. You've really gotten me thinking lately, and I've been meaning to start a blog for a long time anyway. Seemed like a good opportunity to finally get one going.

**Published on May 28th, 2021**

### What is `attr_reader`?

It's common to see Ruby classes expose instance variables using a special class method called `attr_reader`, eg:

```ruby
class Email
  attr_reader :subject, :body

  def initialize(subject, body)
    @subject = subject
    @body = body
  end
end

email = Email.new('Check this out', 'Ruby rocks')
puts email.subject  # => prints "Check this out"
```

As you can see, `attr_reader :name` defines the `#name` method on our `Email` class. The `#name` method simply returns the value of the `@name` instance variable.

Ruby also features two other class methods, `attr_writer` and `attr_accessor`. The former defines a method for assigning a value to an instance variable (eg. `#name=`) while the latter defines both the getter and the setter (i.e. both `#name` _and_ `#name=`).

Why would you ever do this? The basic premise is that instance variables are _private_, meaning nobody outside the class can get or set them. By wrapping ivars with `attr_reader` and friends, they are now available to the outside world.

### Why Methods are Almost Always Better

In my opinion, by far the biggest benefit of `attr_reader` is that it exposes instance variables as methods. Why are methods better? In a word, _inheritance_.

There's no way to override instance variables in Ruby. Consider an ivar-only version of our `Email` class from earlier (notice the addition of the `#deliver_to` method):

```ruby
require 'mail'

class Email
  def initialize(subject, body)
    @subject = subject
    @body = body
  end

  def deliver_to(address)
    mail = Mail.new
    mail[:from] = 'no-reply@camerondutro.com'
    mail[:to] = address
    mail[:subject] = @subject
    mail[:body] = @body
    mail.deliver!
  end
end
```

Let's say I want to add a signature at the end of the email body. To do so, I'll create a new `EmailWithSignature` class that inherits from `Email`:

```ruby
class EmailWithSignature < Email
end
```

Somewhere in my new class, I need to append the signature to the body. I only really have two options:

1. Override `#initialize` and append the signature to `@body`.
1. Override `#deliver_to` so it appends the signature on send.

Neither of these options feel particularly "clean." Both `#initialize` and `#deliver_to` accept arguments, and those arguments can change over time. If I override one of them, I have to make sure my derived `EmailWithSignature` class changes whenever `Email` does.

If I choose to override `#deliver_to`, I have to copy/paste the logic into `EmailWithSignature` in order to change the content of the body, or potentially reassign `@body` before calling `super`. Yuck.

Instead, let's wrap our instance variables in `attr_reader`s (see above). Now the derived class can simply override the `body` method, which will always accept zero arguments:

```ruby
class EmailWithSignature < Email
  def body
    super + "\n\n-Cameron Dutro\nInternational Man of Mystery"
  end
end
```

Much easier, much cleaner.

The limitations of the ivar approach have bitten me numerous times in my professional career. In most cases, requirements had changed and I found myself needing to extend an existing class. Using `attr_reader` would have given me the "hooks" I needed to non-intrusively modify the class's behavior.

Remember that derived classes can call your private methods. If you're worried about someone else messing with your encapsulated data, just make your `attr_reader`s private:

```ruby
class Email
  attr_reader :subject, :body
  private :subject, :body

  def initialize(subject, body)
    @subject = subject
    @body = body
  end
end

email = Email.new('Check this out', 'Ruby rocks')
puts email.subject  # => raises a NoMethodError
```

However, I prefer to make all of mine public. That's because I believe encapsulation _doesn't exist_.

### The Problem with Encapsulation

If you've gone through any sort of formal computer science training, chances are you've been taught the four main pillars of object-oriented programming: **inheritance**, **abstraction**, **polymorphism**, and **encapsulation**.

As you probably already know, encapsulation prevents direct access to an object's state. In Ruby, that means preventing direct access to an object's instance variables. The idea is that the object and the object alone should be able to mutate its state, perhaps to maintain some invariants, etc.

However in the vast majority of object-oriented systems, much of what we think of as the internal, encapsulated state of an object is actually _shared_ state. Let's take a look at a class (granted, a very naïve one) that represents an email address:

```ruby
class EmailAddress
  def initialize(address)
    unless address.include?('@')
      raise InvalidAddressError, "the address '#{address}' is invalid"
    end

    @address = address
  end

  def user
    @address.split('@')[0]
  end

  def host
    @address.split('@')[1]
  end
end
```

Our class nicely encapsulates `@address`. Nobody else should be able to mess with it right?

Wrong!

```ruby
address_str = 'foo@bar.com'
address = EmailAddress.new(address_str)
address.host  # => "bar.com"
address_str.replace('woops!')
address.host  # => nil
```

Woops! Since everything in Ruby is passed by reference, it's entirely possible for the data given to an object to change without the object's knowledge. In other words, _encapsulation can be easily bypassed_.

It doesn't matter if we use ivars or make the `attr_reader` private. There's always the chance someone else is holding on to a reference to our "private" data and can mutate it at will.

To me, that's a pretty big deal. It means encapsulation is kind of a lie. If you assign ivars in your class's constructor from passed-in data, you might as well expose them with `attr_reader`s. They're basically public anyway.

### Encapsulating Better

Hold on. If encapsulation doesn't exist, then doesn't that call all of object-oriented programming into question?

Maybe, but I'm not the right person to say one way or the other. I happen to really enjoy object-oriented programming. It fits the way my brain works.

But just like a number of aspects of software development, programming well requires _discipline_. I posit that large object-oriented systems stay afloat because programmers, mostly unconsciously, develop an understanding of the nuances of encapsulation and evolve habits to avoid the major pitfalls. That's certainly been the case for me. It was only in thinking deeply about this article that I began to ask myself why, for example, reassigning instance variables feels wrong to me.

To that end, I like to follow these rules:

1. Only set instance variables once. After they are set, treat them like constants.
1. Copy objects before mutating them.

The goal here is to prevent our objects from changing except at well-known points in time.

#### Only Set Instance Variables Once

In most cases, I think reassigning instance variables is a code smell. If your object needs to change what data it references, _it should have asked for different data at initialization_.

**NOTE**: Methods that use instance variables to memoize the result of a lazily evaluated expression are ok because, although the object didn't ask for the data at initialization, it still only sets the instance variable once.

The less your object's state changes after initialization, the less uncertainty you introduce into the system.

#### Copy Objects Before Mutating Them

Consider this classic example of pass-by-reference mayhem:

```ruby
def compliment(name)
  puts name << ', you rock!'
end

name = 'Cameron'
compliment(name)
name  # => "Cameron, you rock!"
```

The caller probably isn't expecting `compliment` to mutate `name`.

The same principle applies to data referenced by an object's instance variables. Mutating only copies of your data prevents these sorts of surprises.

### Back to `attr_reader`

Ok, but what does all this have to do with `attr_reader`?

In his usual erudite manner, Jason lays out the case against `attr_reader` with the following statement:

> **Adding a public `attr_reader` throws away the benefits of encapsulation**
>
> Private instance variables are useful for the same reason as private methods: **because you know they’re not depended on by outside clients**.
>
> If I have a class that has an instance variable called `@price`, I know that I can rename that instance variable to `@cost` or change it to `@price_cents` (changing the whole meaning of the value) or even kill `@price` altogether. What I want to do with `@price` is 100% my business. This is great.

Hopefully I've shown in this article why encapsulation is more or less a myth. There's no way to know who else may reference the same data as your instance variables, so it very well may not be "100% your business." This is especially true if one of your methods returns it somehow, perhaps wrapped by another object.

I do agree that adding `attr_reader :price` changes the class's public interface, making it more difficult to change in the future. Unless you're developing library code or a gem however, I think the public interface argument is fairly weak. As Jason says a few paragraphs earlier, if a naming issue causes a problem in your application, your application probably isn't tested well enough.

### Conclusion

My takeaway message is this: encapsulation doesn't provide the guarantees we were taught it does. There's no real benefit to "hiding" data inside an object, since that data may be referenced - privately or publicly - by any number of other objects. You might as well expose your instance variables with `attr_reader` for the inheritance benefits.

Disagree? [Hit me up](https://twitter.com/camertron) on Twitter.
