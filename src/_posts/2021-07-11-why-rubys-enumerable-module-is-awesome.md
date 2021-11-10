---
layout: post
title: "Why Ruby's Enumerable Module is Awesome"
date: 2021-07-10 10:00:00 -0700
author: cameron
published: true
---

This post was originally written in 2014 at the beginning of my tenure at Lumos Labs. At the time, I was a member of the Learning Team, an "extracurricular" group that met bi-weekly to discuss cool things we were learning about technology. We organized tech meetups in our office space, streamed live Google IO talks over the projector during lunch, and sent out a digest email to our colleagues every two weeks with links to various learning resources. I ended up writing a few longer-form articles for these email blasts. What follows is an embellished version of one of those articles.

<hr>

You're probably familiar with the concept of "iteration" in computer programming. It's the idea of examining - or iterating over - each of the things in a collection.

Perhaps the most obvious thing you can iterate over is an array. The elements of an array are accessed by their index, so iterating is pretty straightforward. Here's an example in pseudocode:

```
array = [5, 3, 8]

for i = 0 to array.length
  do something with array[i]
end
```

This code iterates over each item in the array. Inside the body of the loop, elements are accessed individually using the `[]` syntax.

We can do the same thing in Ruby using the `for` keyword:

```ruby
array = [5, 3, 8]

for i in 0...3
  # do something with array[i]
end
```

### `#each`

The truth is though, in 11 years writing Ruby code, I've never, not even once, seen anyone use a `for` loop. Instead, Ruby programmers reach for the `#each` method. `#each` yields each element to the given block. Here's a quick example that prints out each of the numbers in the array:

```ruby
[5, 3, 8].each do |number|
  puts number
end
```

Not only is the code easier to read with `#each`, it's more obvious what it does. `#each` abstracts away the details of the iteration logic and lets the programmer focus on their goal: handling one element at a time.

### Sum of Integers

Let's get a little more adventurous and use Ruby to compute the sum of all the elements in our array.

```ruby
sum = 0

[5, 3, 8].each do |number|
  sum += number
end
```

When `#each` returns, `sum` will contain 16.

### The Magic of `#inject`

It would be great if we could get rid of that extra local variable, `sum`. Fortunately, Ruby's `#inject` method can help. Here's how we might use it to sum up the elements in our array:

```ruby
[5, 3, 8].inject(0) do |sum, number|
  sum + number
end
```

Pretty cool, eh? The `#inject` method calls the block for each number, passing the _previous_ result as the first argument and the next element from the array as the second argument (the previous result is simply the value returned by the block during the previous iteration).

I can hear some of you saying, "Whoa, slow down. What just happened?!" Ok, let's break it down step-by-step.

1. First iteration (`sum` is set to the initial value passed to `#inject`, which is `0`)
    ```ruby
    [5, 3, 8].inject(0) do |sum, number|
      # sum = 0 (initial value passed to #inject above)
      # number = 5 (first element of array)
      # 0 + 5 = 5
      sum + number
      # 5 becomes the return value of the block
    end
    ```
1. Second iteration
    ```ruby
    [5, 3, 8].inject(0) do |sum, number|
      # sum = 5 (from previous iteration)
      # number = 3 (second element of array)
      # 5 + 3 = 8
      sum + number
      # 8 becomes the return value of the block
    end
    ```
1. Third iteration
    ```ruby
    [5, 3, 8].inject(0) do |sum, number|
      # sum = 8 (from previous iteration)
      # number = 8 (third element of array)
      # 8 + 8 = 16
      sum + number
      # 16 becomes the return value of the block
    end
    ```

Since there are only three elements in the array, iteration stops and the final sum of 16 is returned.

### Even More Magic

As it happens, there's an even more succinct way to do this. `#inject` supports passing a symbol as the first argument. The symbol must be the name of a method that can be called on the elements of the array. Since we're adding in this case, we can pass the `:+` symbol, which represents the `#+` method on `Integer`:

```ruby
[5, 3, 8].inject(:+)
```

No block necessary! `#inject` automatically keeps track of the previous value and adds it to the next element on each iteration. As above, this code produces the value 16.

### The `Enumerable` Module

The `#inject` method is only one of the **many** methods provided by Ruby's `Enumerable` module. `Enumerable` is included in `Array`, `Hash`, and other core classes, providing a uniform way to iterate over all the items in a collection.

This is where things get really interesting - `Enumerable` has a _ton_ of cool methods. Need to process a collection in a specific or special way? Chances are there's an `Enumerable` method (or methods) for it.

Accordingly, let's take a look at a couple of the other useful tools in the `Enumerable` toolkit.

### `Enumerable#map`

`#map` is probably the next most commonly used `Enumerable` method after `#each`. It collects the results of the block into an array and returns it. For example, here's how we might multiply every element in our array by 2:

```ruby
result = [5, 3, 8].map do |number|
  number * 2
end
```

After running this code, `result` will contain `[10, 6, 16]`.

### `Enumerable#each_slice`

Another great example of `Enumerable`'s utility is `each_slice`, which yields sub arrays of the given length to the block. For example, the following code turns this flat array of ingredients into a hash:

```ruby
recipe = {}.tap do |result|
  [:eggs, 2, :carrots, 1, :bell_peppers, 3].each_slice(2) do |food, amount|
    result[food] = amount
  end
end
```

The desired length of each slice is passed as the first argument to `#each_slice`, eg. `each_slice(2)` as above.

After running this code, `recipe` will contain `{ eggs: 2, carrots: 1, bell_peppers: 3 }`.

As an aside, notice that you can also assign the elements of the sub-array to individual block parameters, eg. `food` and `amount`. If only one parameter is specified, it will contain an array with two elements.

### But Wait, There's More!

Check out the plethora of other `Enumerable` methods in Ruby's [official documentation](https://ruby-doc.org/core-3.0.1/Enumerable.html).

### Custom Enumerators

We've seen a few examples of `Enumerable`'s awesomeness so far, but in my opinion its real power can only be truly experienced in combination with custom enumerators.

Let's say you're writing a client that communicates with a search API. The API returns search results in pages (i.e. batches) of 50.

```ruby
class SearchClient
  def search_for(keywords, page: 1)
    response = http_get('/search', keywords: keywords, page: page)
    JSON.parse(response.body)
  end

  def http_get(path, **params)
    ...
  end
end
```

To fetch all the search results, the caller makes multiple calls to the `#search_for` method.

```ruby
client = SearchClient.new
page = 1

loop do
  results = client.search_for('avocado', page: page)
  break if results.empty?

  results.each do |result|
    # do something with search result
  end

  page += 1
end
```

This approach works great, but forces the caller to understand how the API works. Specifically it requires the caller to know that results are paginated and that an empty result set indicates all results have been retrieved.

Let's move the pagination logic into a separate class.

```ruby
class SearchClient
  def search_for(keywords)
    SearchResultSet.new(self, keywords)
  end

  def http_get(path, **params)
    ...
  end
end

class SearchResultSet
  attr_reader :client, :keywords

  def initialize(client, keywords)
    @client = client
    @keywords = keywords
  end

  def each
    page = 1

    loop do
      results = client.http_get('/search', keywords: keywords, page: page)
      break if results.empty?

      JSON.parse(results).each do |result|
        yield result
      end

      page += 1
    end
  end
end
```

Notice how our `SearchResultSet` class transparently encapsulates the API's pagination behavior. The caller no longer has to know how the API works. Instead, callers simply fetch results and iterate over them using a mechanism they're already familar with - `#each`.

Here's an example.

```ruby
client = SearchClient.new
results = client.search_for('avocados')
results.each do |result|
  puts result['id']  # or whatever
end
```

### Mixing in `Enumerable`

Remember when I said a bunch of Ruby's core classes like `Array` and `Hash` include `Enumerable`? I meant that they quite literally `include` the `Enumerable` module.

And because `Enumerable` is just a regular 'ol Ruby module, **_you can include it too_**.

In fact, `Enumerable` was _designed_ to be mixed into (i.e. `include`d) into any Ruby class. The only requirement is that the class defines an `#each` method.

**_That's because every other `Enumerable` method is implemented in terms of `#each`_**.

Yes, that's right. Simply defining an `#each` method and `include`ing the `Enumerable` module into your class gives you all the power of `Enumerable` **FOR FREE**. In other words, you get `#map`, `#each_slice`, and all the other `Enumerable` methods without having to lift a finger.

Let's `include Enumerable` into our `SearchResultSet` class. With that very minimal effort, this is now possible:

```ruby
client = SearchClient.new
results = client.search_for('avocados')
ids = results.map { |result| result['id'] }
```

Notice that we didn't define `#map` on `SearchResultSet` directly - it came from `Enumerable`. By the same token, `#each_slice`, `#each_cons`, `#inject`, and many, many other useful methods are now available too. What's more, they all Just Work. Not bad for a few lines of code.

### The Case of the Missing Block

There's one last thing I'd like to talk about before wrapping up, and that's lazy enumerators.

What happens if we call `SearchResultSet#each` without a block?

```ruby
results.each
# => LocalJumpError: yield called out of block
```

Hmm, that's weird. I don't get an error if I try the same thing on an array:

```ruby
[5, 3, 8].each
# => #<Enumerator: [5, 3, 8]:each>
```

In Ruby, the `yield` keyword doesn't check to make sure the caller passed a block. We can therefore avoid the `LocalJumpError` by checking for the block, and bailing out if one wasn't passed.

```ruby
def each
  return unless block_given?

  page = 1
  ...
end
```

Ok, let's try that again:

```ruby
results.each
# => nil
```

Not quite what we wanted, but at least there's no error. We need to figure out how to return the same kind of `Enumerator` object we got when calling a blockless `#each` on an array.

### `Kernel#to_enum`

Fortunately, there's an easy way to convert any function into an `Enumerator` - Ruby's `Kernel#to_enum`.

```ruby
def each
  return to_enum(:each) unless block_given?

  page = 1
  ...
end
```

Now, calling `SearchResultSet#each` without a block will return an `Enumerator` object.

```ruby
results.each
# => #<Enumerator: #<SearchResultSet:0x00007fa715aaee70 @client=#<SearchClient:0x00007fa715aaeec0>, @keywords="avocado">:each>
```

### Chaining Enumerators

Ok, so why do this? While not particularly important for the `#each` method, returning an `Enumerator` when called without a block is the way all the other `Enumerable` methods work. I think it's a good idea to be consistent.

Another less important reason is to enable chaining. `Enumerator`s respond to all the methods in `Enumerable`, meaning things like this are possible:

```ruby
enum = results.each
enum.map.with_index do |result, idx|
  # result is the search result, and idx is a counter automatically
  # incremented on each iteration
end
```

### Conclusion

Enumerators and the `Enumerable` module are my all-time favorite Ruby features. They are what got me hooked on Ruby when I first started using it back in 2011. No other language I've used has been able to match the same level of expressiveness and flexibility.

I hope this post inspires you to use `Enumerable` in new and interesting ways!
