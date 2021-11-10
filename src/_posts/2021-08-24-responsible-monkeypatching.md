---
layout: post
title: "Responsible Monkeypatching"
date: 2021-08-24 12:00:00 -0700
author: cameron
published: true
---

This is a [post](https://blog.appsignal.com/2021/08/24/responsible-monkeypatching-in-ruby.html) I wrote for the AppSignal blog about how to monkeypatch without making a mess :)

<hr>

<link rel="canonical" href="https://blog.appsignal.com/2021/08/24/responsible-monkeypatching-in-ruby.html">

When I first started writing Ruby code professionally back in 2011, one of the things that impressed me the most about the language was its flexibility. It felt as though with Ruby, everything was possible. Compared to the rigidity of languages like C# and Java, Ruby programs almost seemed like they were _alive_.

Consider how many incredible things you can do in a Ruby program. You can define and delete methods at will. You can call methods that don't exist. You can conjure entire nameless classes out of thin air. It's absolutely wild.

But that's not where the story ends. While you can apply these techniques inside your own code, Ruby also lets you apply them to anything loaded into the virtual machine. In other words, you can mess with other people's code as easily as you can your own.

## What Are Monkeypatches?

Enter the _monkeypatch_.

In short, monkeypatches "monkey with" existing code. The existing code is often code you don't have direct access to, like code from a gem or from the Ruby standard library. Patches are usually designed to alter the original code's behavior to fix a bug, improve performance, etc.

The most unsophisticated monkeypatches reopen ruby classes and modify behavior by adding or overriding methods.

This reopening idea is core to Ruby's object model. Whereas in Java classes can only be defined once, Ruby classes (and modules for that matter) can be defined multiple times. When we define a class a second, a third, a fourth time, etc, we say that we're _reopening_ it. Any new methods we define are added to the existing class definition, and can be called on instances of that class.

This short example illustrates the class reopening concept:

```ruby
class Sounds
  def honk
    "Honk!"
  end
end

class Sounds
  def squeak
    "Squeak!"
  end
end

sounds = Sounds.new
sounds.honk    # => "Honk!"
sounds.squeak  # => "Squeak!"
```

Notice that both the `#honk` and `#squeak` methods are available on the `Sounds` class through the magic of reopening.

Monkeypatching is essentially the act of reopening classes in 3rd-party code.

## Is Monkeypatching Dangerous?

If the previous sentence scared you, that's probably a good thing. Monkeypatching, especially when done carelessly, can cause real chaos.

Consider for a moment what would happen if we were to redefine `Array#<<`:

```ruby
class Array
  def <<(*args)
    # do nothing 😈
  end
end
```

With these four lines of code, every single array instance in the entire program is now broken.

What's more, the original implementation of `#<<` is gone. Aside from restarting the Ruby process, there's no way to get it back.

## When Monkeypatching Goes Horribly Wrong

Back in 2011, I worked for a prominent social networking company. At the time, the codebase was a massive Rails monolith running on Ruby 1.8.7. Several hundred engineers contributed to the codebase on a daily basis, and the pace of development was very fast.

At one point my team decided to monkeypatch `String#%` to make writing plurals easier for internationalization purposes. Here's an example of what our patch could do:

```ruby
replacements = {
  horse_count: 3,
  horses: {
    one: "is 1 horse",
    other: "are %{horse_count} horses"
  }
}

# "there are 3 horses in the barn"
"there %{horse_count:horses} in the barn" % replacements
```

We wrote up the patch and eventually got it deployed into production...only to find that it didn't work. Our users were seeing strings with literal `%{...}` characters instead of nicely pluralized text. It didn't make sense. The patch had worked perfectly well in the development environment on my laptop. Why wasn't it working in production?

Initially, we thought we'd found a bug in Ruby itself, only to later find that a production Rails console produced a different result than a Rails console in development. Since both consoles ran on the same Ruby version, we could rule out a bug in the Ruby standard library. Something else was going on.

After several days of head-scratching, a co-worker was able to track down a Rails initializer that added _another_ implementation of `String#%` that none of us had seen before. To further complicate things, this earlier implementation also contained a bug, so the results we saw in the production console differed from Ruby's official documentation.

That's not the end of the story though. In tracking down the earlier monkeypatch, we also found no less than three more, _all patching the same method._ We looked at each other in horror. How did this ever work??

We eventually chalked the inconsistent behavior up to Rails' eager loading. In development, Rails lazy loads Ruby files, i.e., only loads them when they are `require`d. In production, however, Rails loads all of the app's Ruby files at initialization. This can throw a big monkey wrench into monkeypatching.

## Consequences of Reopening a Class

In this case, each of the monkeypatches reopened the `String` class and effectively replaced the existing version of the `#%` method with another one. There are several major pitfalls to this approach:

1. The last patch applied "wins", meaning behavior is dependent on load order.
1. There's no way to access the original implementation.
1. Patches leave almost no audit trail, which makes them very difficult to find later.

Not surprisingly, perhaps, we ran into all of these.

At first, we didn't even know there were other monkeypatches at play. Because of the bug in the winning method, it appeared the original implementation was broken. When we discovered the other competing patches, it was impossible to tell which won without adding copious `puts` statements.

Finally, even when we did discover which method won in development, a different one would win in production. It was also programmatically difficult to tell which patch had been applied last since Ruby 1.8 didn't have the wonderful `Method#source_location` method we have now.

I spent at least a week trying to figure out what was going on, time I essentially wasted chasing an entirely avoidable problem.

Eventually, we decided to introduce the `LocalizedString` wrapper class with an accompanying `#%` method. Our `String` monkeypatch then simply became this:

```ruby
class String
  def localize
    LocalizedString.new(self)
  end
end
```

## When Monkeypatching Fails

In my experience, monkeypatches often fail for one of two reasons:

1. **The patch itself is broken.** In the codebase I mentioned above, not only were there several competing implementations of the same method, but the method that "won" didn't work.
1. **Assumptions are invalid.** The host code has been updated and the patch no longer applies as written.

Let's look at the second bullet point in more detail.

## Even the Best-Laid Plans...

Monkeypatching often fails for the same reason you reached for it in the first place - because you don't have access to the original code. For precisely that reason, the original code can change out from under you.

Consider this example in a gem your app depends on:

```ruby
class Sale
  def initialize(amount, discount_pct, tax_rate = nil)
    @amount = amount
    @discount_pct = discount_pct
    @tax_rate = tax_rate
  end

  def total
    discounted_amount + sales_tax
  end

  private

  def discounted_amount
    @amount * (1 - @discount_pct)
  end

  def sales_tax
    if @tax_rate
      discounted_amount * @tax_rate
    else
      0
    end
  end
end
```

Wait, that's not right. Sales tax should be applied to the full amount, not the discounted amount. You submit a pull request to the project. While you're waiting for the maintainer to merge your PR, you add this monkeypatch to your app:

```ruby
class Sale
  private

  def sales_tax
    if @tax_rate
      @amount * @tax_rate
    else
      0
    end
  end
end
```

It works perfectly. You check it in and forget about it.

Everything is fine for a long time. Then one day the finance team sends you an email asking why the company hasn't been collecting sales tax for a month.

Confused, you start digging into the issue and eventually notice one of your co-workers recently updated the gem that contains the `Sale` class. Here's the updated code:

```ruby
class Sale
  def initialize(amount, discount_pct, sales_tax_rate = nil)
    @amount = amount
    @discount_pct = discount_pct
    @sales_tax_rate = sales_tax_rate
  end

  def total
    discounted_amount + sales_tax
  end

  private

  def discounted_amount
    @amount * (1 - @discount_pct)
  end

  def sales_tax
    if @sales_tax_rate
      discounted_amount * @sales_tax_rate
    else
      0
    end
  end
end
```

Looks like one of the project maintainers renamed the `@tax_rate` instance variable to `@sales_tax_rate`. The monkeypatch checks the value of the old `@tax_rate` variable, which is always `nil`. Nobody noticed because no errors were ever raised. The app chugged along as if nothing had happened.

## Why Monkeypatch?

Given these examples, it might seem like monkeypatching just isn't worth the potential headaches. So why do we do it? In my opinion, there are three major use-cases:

1. To fix broken or incomplete 3rd-party code.
1. To quickly test a change or multiple changes in development.
1. To wrap existing functionality with instrumentation or annotation code.

In some cases, the _only_ viable way to address a bug or performance issue in 3rd-party code is to apply a monkeypatch.

But with great power comes great responsibility.

## Monkeypatching Responsibly

I like to frame the monkeypatching conversation around responsibility instead of whether or not it's good or bad. Sure, monkeypatching can cause chaos when done poorly. However, if done with some care and diligence, there's no reason to avoid reaching for it when the situation warrants it.

Here's the list of rules I try to follow:

1. Wrap the patch in a module with an obvious name and use `Module#prepend` to apply it.
1. Make sure you're patching the right thing.
1. Limit the patch's surface area.
1. Give yourself escape hatches.
1. Over-communicate.

For the remainder of this article, we're going to use these rules to write up a monkeypatch for Rails' `DateTimeSelector` so it optionally skips rendering discarded fields. This is a change I actually tried to make to Rails a few years ago. [You can find the details here](https://github.com/rails/rails/pull/31533).

You don't have to know much about discarded fields to understand the monkeypatch, though. At the end of the day, all it does is replace a single method called `build_hidden` with one that effectively does nothing.

Let's get started!

### Use `Module#prepend`

In the codebase I encountered in my previous role, all the implementations of `String#%` were applied by reopening the `String` class. Here's an augmented list of the drawbacks I mentioned earlier:

1. Errors appear to have originated from the host class or module instead of from the patch code.
1. Any methods you define in the patch replace existing methods with the same name, meaning there's no way to invoke the original implementation.
1. There's no way to know which patches were applied and therefore which methods "won".
1. Patches leave almost no audit trail, which makes them very difficult to find later.

Instead, it's much better to wrap your patch in a module and apply it using `Module#prepend`. Doing so leaves you free to call the original implementation, and a quick call to `Module#ancestors` will show the patch in the inheritance hierarchy so it's easier to find if things go wrong.

Finally, a simple `prepend` statement is easy to comment out if you need to disable the patch for some reason.

Here are the beginnings of a module for our Rails monkeypatch:

```ruby
module RenderDiscardedMonkeypatch
end

ActionView::Helpers::DateTimeSelector.prepend(
  RenderDiscardedMonkeypatch
)
```

### Patch the Right Thing

If you take one thing away from this article, let it be this: don't apply a monkeypatch unless you know you're patching the right code. In most cases, it should be possible to verify programmatically that your assumptions still hold (this is Ruby after all). Here's a checklist:

1. Make sure the class or module you're trying to patch exists.
1. Make sure methods exist and have the right arity.
1. If the code you're patching lives in a gem, check the gem's version.
1. Bail out with a helpful error message if assumptions don't hold.

Right off the bat, our patch code has made a pretty important assumption. It assumes a constant called `ActionView::Helpers::DateTimeSelector` exists and is a class or module.

#### Check Class/Module

Let's make sure that constant exists before trying to patch it:

```ruby
module RenderDiscardedMonkeypatch
end

const = begin
  Kernel.const_get('ActionView::Helpers::DateTimeSelector')
rescue NameError
end

if const
  const.prepend(RenderDiscardedMonkeypatch)
end
```

Great, but now we've leaked a local variable (`const`) into the global scope. Let's fix that:

```ruby
module RenderDiscardedMonkeypatch
  def self.apply_patch
    const = begin
      Kernel.const_get('ActionView::Helpers::DateTimeSelector')
    rescue NameError
    end

    if const
      const.prepend(self)
    end
  end
end

RenderDiscardedMonkeypatch.apply_patch
```

#### Check Methods

Next, let's introduce the patched `build_hidden` method. Let's also add a check to make sure it exists and accepts the right number of arguments (i.e. has the right arity). If those assumptions don't hold, something's probably wrong:

```ruby
module RenderDiscardedMonkeypatch
  class << self
    def apply_patch
      const = find_const
      mtd = find_method(const)

      if const && mtd && mtd.arity == 2
        const.prepend(self)
      end
    end

    private

    def find_const
      Kernel.const_get('ActionView::Helpers::DateTimeSelector')
    rescue NameError
    end

    def find_method(const)
      return unless const
      const.instance_method(:build_hidden)
    rescue NameError
    end
  end

  def build_hidden(type, value)
    ''
  end
end

RenderDiscardedMonkeypatch.apply_patch
```

#### Check Gem Versions

Finally, let's check that we're using the right version of Rails. If Rails gets upgraded, we might need to update the patch too (or get rid of it entirely).

```ruby
module RenderDiscardedMonkeypatch
  class << self
    def apply_patch
      const = find_const
      mtd = find_method(const)

      if const && mtd && mtd.arity == 2 && rails_version_ok?
        const.prepend(self)
      end
    end

    private

    def find_const
      Kernel.const_get('ActionView::Helpers::DateTimeSelector')
    rescue NameError
    end

    def find_method(const)
      return unless const
      const.instance_method(:build_hidden)
    rescue NameError
    end

    def rails_version_ok?
      Rails::VERSION::MAJOR == 6 && Rails::VERSION::MINOR == 1
    end
  end

  def build_hidden(type, value)
    ''
  end
end

RenderDiscardedMonkeypatch.apply_patch
```

#### Bail Out Helpfully

If your verification code uncovers a discrepancy between expectations and reality, it's a good idea to raise an error or at least print a helpful warning message. The idea here is to alert you and your co-workers when something seems amiss.

Here's how we might modify our Rails patch:

```ruby
module RenderDiscardedMonkeypatch
  class << self
    def apply_patch
      const = find_const
      mtd = find_method(const)

      unless const && mtd && mtd.arity == 2
        raise "Could not find class or method when patching "\
          "ActionView's date_select helper. Please investigate."
      end

      unless rails_version_ok?
        puts "WARNING: It looks like Rails has been upgraded since "\
          "ActionView's date_select helper was monkeypatched in "\
          "#{__FILE__}. Please reevaluate the patch."
      end

      const.prepend(self)
    end

    private

    def find_const
      Kernel.const_get('ActionView::Helpers::DateTimeSelector')
    rescue NameError
    end

    def find_method(const)
      return unless const
      const.instance_method(:build_hidden)
    rescue NameError
    end

    def rails_version_ok?
      Rails::VERSION::MAJOR == 6 && Rails::VERSION::MINOR == 1
    end
  end

  def build_hidden(type, value)
    ''
  end
end

RenderDiscardedMonkeypatch.apply_patch
```

### Limit Surface Area

While it may seem perfectly innocuous to define helper methods in a monkeypatch, remember that any methods defined via `Module#prepend` will override existing ones through the magic of inheritance. While it might seem as though a host class or module doesn't define a particular method, it's difficult to know for sure. For this reason, I try only to  define methods I intend to patch.

Note that this also applies to methods defined in the object's singleton class, i.e. methods defined inside `class << self`.

Here's how to modify our Rails patch to only replace the one `#build_hidden` method:

```ruby
module RenderDiscardedMonkeypatch
  class << self
    def apply_patch
      const = find_const
      mtd = find_method(const)

      unless const && mtd && mtd.arity == 2
        raise "Could not find class or method when patching"\
          "ActionView's date_select helper. Please investigate."
      end

      unless rails_version_ok?
        puts "WARNING: It looks like Rails has been upgraded since"\
          "ActionView's date_selet helper was monkeypatched in "\
          "#{__FILE__}. Please reevaluate the patch."
      end

      const.prepend(InstanceMethods)
    end

    private

    def find_const
      Kernel.const_get('ActionView::Helpers::DateTimeSelector')
    rescue NameError
    end

    def find_method(const)
      return unless const
      const.instance_method(:build_hidden)
    rescue NameError
    end

    def rails_version_ok?
      Rails::VERSION::MAJOR == 6 && Rails::VERSION::MINOR == 1
    end
  end

  module InstanceMethods
    def build_hidden(type, value)
      ''
    end
  end
end

RenderDiscardedMonkeypatch.apply_patch
```

### Give Yourself Escape Hatches

When possible, I like to make my monkeypatch's functionality opt-in. That's only really an option if you have control over where the patched code is invoked. In the case of our Rails patch, it's doable via the `@options` hash in `DateTimeSelector`:

```ruby
module RenderDiscardedMonkeypatch
  class << self
    def apply_patch
      const = find_const
      mtd = find_method(const)

      unless const && mtd && mtd.arity == 2
        raise "Could not find class or method when patching"\
          "ActionView's date_select helper. Please investigate."
      end

      unless rails_version_ok?
        puts "WARNING: It looks like Rails has been upgraded since"\
          "ActionView's date_selet helper was monkeypatched in "\
          "#{__FILE__}. Please reevaluate the patch."
      end

      const.prepend(InstanceMethods)
    end

    private

    def find_const
      Kernel.const_get('ActionView::Helpers::DateTimeSelector')
    rescue NameError
    end

    def find_method(const)
      return unless const
      const.instance_method(:build_hidden)
    rescue NameError
    end

    def rails_version_ok?
      Rails::VERSION::MAJOR == 6 && Rails::VERSION::MINOR == 1
    end
  end

  module InstanceMethods
    def build_hidden(type, value)
      if @options.fetch(:render_discarded, true)
        super
      else
        ''
      end
    end
  end
end

RenderDiscardedMonkeypatch.apply_patch
```

Nice! Now callers can opt-in by calling the `date_select` helper with the new option. No other codepaths are affected:

```ruby
date_select(@user, :date_of_birth, {
  order: [:month, :day],
  render_discarded: false
})
```

### Over-Communicate

The last piece of advice I have for you is perhaps the most important - communicating what your patch does and when it's time to re-examine it. Your goal with monkeypatches should always be to eventually remove the patch altogether. To that end, a responsible monkeypatch includes comments that:

1. Describe what the patch does.
1. Explain why the patch is necessary.
1. Outline the assumptions the patch makes.
1. Specify a date in the future when your team should reconsider alternative solutions, like pulling in an updated gem.
1. Include links to relevant pull requests, blog posts, StackOverflow answers, etc.

You might even print a warning or fail a test on a predetermined date to urge the team to reconfirm the patch's assumptions and consider whether or not it's still necessary.

Here's the final version of our Rails `date_select` patch, complete with comments and a date check:

```ruby
# ActionView's date_select helper provides the option to "discard" certain
# fields. Discarded fields are (confusingly) still rendered to the page
# using hidden inputs, i.e. <input type="hidden" />. This patch adds an
# additional option to the date_select helper that allows the caller to
# skip rendering the chosen fields altogether. For example, to render all
# but the year field, you might have this in one of your views:
#
# date_select(:date_of_birth, order: [:month, :day])
#
# or, equivalently:
#
# date_select(:date_of_birth, discard_year: true)
#
# To avoid rendering the year field altogether, set :render_discarded to
# false:
#
# date_select(:date_of_birth, discard_year: true, render_discarded: false)
#
# This patch assumes the #build_hidden method exists on
# ActionView::Helpers::DateTimeSelector and accepts two arguments.
#
module RenderDiscardedMonkeypatch
  class << self
    EXPIRATION_DATE = Date.new(2021, 8, 15)

    def apply_patch
      if Date.today > EXPIRATION_DATE
        puts "WARNING: Please re-evaluate whether or not the ActionView "\
          "date_select patch present in #{__FILE__} is still necessary."
      end

      const = find_const
      mtd = find_method(const)

      # make sure the class we want to patch exists;
      # make sure the #build_hidden method exists and accepts exactly
      # two arguments
      unless const && mtd && mtd.arity == 2
        raise "Could not find class or method when patching "\
          "ActionView's date_select helper. Please investigate."
      end

      # if rails has been upgraded, make sure this patch is still
      # necessary
      unless rails_version_ok?
        puts "WARNING: It looks like Rails has been upgraded since "\
          "ActionView's date_select helper was monkeypatched in "\
          "#{__FILE__}. Please re-evaluate the patch."
      end

      # actually apply the patch
      const.prepend(InstanceMethods)
    end

    private

    def find_const
      Kernel.const_get('ActionView::Helpers::DateTimeSelector')
    rescue NameError
      # return nil if the constant doesn't exist
    end

    def find_method(const)
      return unless const
      const.instance_method(:build_hidden)
    rescue NameError
      # return nil if the method doesn't exist
    end

    def rails_version_ok?
      Rails::VERSION::MAJOR == 6 && Rails::VERSION::MINOR == 1
    end
  end

  module InstanceMethods
    # :render_discarded is an additional option you can pass to the
    # date_select helper in your views. Use it to avoid rendering
    # "discarded" fields, i.e. fields marked as discarded or simply
    # not included in date_select's :order array. For example,
    # specifying order: [:day, :month] will cause the helper to
    # "discard" the :year field. Discarding a field renders it as a
    # hidden input. Set :render_discarded to false to avoid rendering
    # it altogether.
    def build_hidden(type, value)
      if @options.fetch(:render_discarded, true)
        super
      else
        ''
      end
    end
  end
end

RenderDiscardedMonkeypatch.apply_patch
```

## Conclusion

I totally get that some of the suggestions I've outlined above might seem like overkill. Our Rails patch contains way more defensive verification code than actual patch code!

Think of all that extra code as a sheath for your broadsword. It's a lot easier to avoid getting cut if it's enveloped in a layer of protection.

![Sword guitar](https://media.giphy.com/media/KFPRdKqy96oaI4HWEn/giphy-downsized.gif)

What really matters, though, is that I feel confident deploying responsible monkeypatches into production. Irresponsible ones are just time bombs waiting to cost you or your company time, money, and developer health.
