---
layout: post
title: "The Case for Service Objects"
date: 2021-05-21 10:17:29 -0700
tags:
  - ruby
  - service objects
  - web development
  - rails
---

This article is a response to Jason Swett's ["Beware of 'service objects' in Rails"](https://www.codewithjason.com/rails-service-objects/) blog post. In it, Jason warns of the dangers of letting service objects rob you of the benefits of object-oriented programming. I've read Jason's post several times, and listened to a number of discussions he's had about service objects on his podcast, [Rails with Jason](https://www.codewithjason.com/rails-with-jason-podcast/).

**By the way, both Jason's blog and podcast are excellent. Go check them out right now 😊**

Just last week, Jason was invited onto the Remote Ruby podcast where he and the panelists [discussed service objects again](https://remoteruby.transistor.fm/129). Something about the converstaion struck a cord with me. I've listened to Jason talk about his distaste for service objects for a long time. I think he's right, but also wrong. What follows are my thoughts on the humble, oft misunderstood, service object.

**Published on May 21st, 2021**

### Intro

Rails has been around for a long time now. It feels weird to write this, but it'll be Rails' 20th birthday in just a few short years. For those of us who've used the framework for a long time, 20 years feels like a pretty incredible milestone.

I started using Rails ~11 years ago, pretty much straight out of college. I worked on Twitter's International Engineering Team on the Twitter Translation Center, a Rails app that managed our large database of localized content and facilitated contributions from thousands of volunteer translators around the world. It was my first time using Ruby, and I absolutely fell in love with it. Ruby and Rails made CakePHP, the framework I was using at the time for my side projects, feel pretty clunky and outmoded. Ruby and Rails are still my favorite language and framework today, and I know many other devs who feel the same way.

Why has Rails had such staying power? I would argue there are two major reasons:

1. The Ruby and Rails communities are nonpareil in the software world, and
1. Rails keeps evolving.

Hotwire is just the latest example of the evolution Rails devs have enjoyed for the last two decades. I invite you to look back on the asset pipeline, action cable, and turbolinks as a few examples from the past that also changed the game.

### We've Evolved Too

While the framework has changed, so have we as Rails developers. A few years ago much noise was made over the "fat model, skinny controller" concept (in case you're not familiar, the idea is to keep your controller code to a minimum and put all your domain logic into the model layer).

In fact, I would posit that a number of the changes in thinking we've gone through as a community have been related to code organization. Where do you put that odd piece of code that doesn't seem to fit in any of Rails' predefined slots?

One of the answers is to give Rails _new_ slots:

1. The [draper gem](https://github.com/drapergem/draper) adds the app/decorators directory for "view models," i.e. view presenters.
1. The [form objects](https://www.codementor.io/@victor_hazbun/complex-form-objects-in-rails-qval6b8kt) design pattern adds the app/forms directory for handling complex forms.
1. The [pundit gem](https://github.com/varvet/pundit) adds the app/policies directory for specifying authorization rules.
1. The [view_component gem](https://github.com/github/view_component) adds the app/components directory for components that encapsulate view code.
1. Etc, etc.

Of course Rails itself also adds new slots from time to time:

1. Rails 3.0 introduced [concerns](https://api.rubyonrails.org/v6.1.3.1/classes/ActiveSupport/Concern.html) and the app/models/concerns folder for augmenting models.
1. Rails 4.2 introduced [active job](https://guides.rubyonrails.org/active_job_basics.html) and the app/jobs folder for background jobs.
1. Also see app/assets, app/channels, etc.

While all these also added awesome new features to Rails, let's not overlook how significant it is that they introduced a bunch of additional slots to help us organize our code better. In fact, you'd probably agree that a _lot_ of Rails' power comes from its predefined folder structure (just ask your favorite React dev 😏).

### Service Objects

Service objects are yet another slot for organizing our Ruby code, albeit a fairly misunderstood one. For instance, although the community has produced a number of gems for creating service objects, we haven't really coalesced around any one of them. That's probably because service objects in their purest form are just Ruby classes with a fancy name.

For example, here's a service object that creates a user:

```ruby
class CreateUser
  def self.call(params)
    User.create(params)
  end
end
```

Now, I hear you saying, "Wait wait, that's not what service objects are!" and you're right. The term "service object" means different things to different people. In my opinion however, here's what a "service object" is:

1. A plain 'ol Ruby object with a `call` method.

That's literally it.

Ok there is one other thing. You may have noticed that the name of the example service object above, `CreateUser`, sounds more like the name of a method than a class. That's intentional.

I like to think of service objects as representing _actions_.

### Skinny Controllers

"Hey," I hear you saying. "Actions... like in controllers?"

Yes! In the applications I've worked on, _**service objects were extracted exclusively from controller actions**_.

This is the major point on which Jason and I differ. Whereas he writes about service objects as being part of the _models_ directory, I think of them as being part of the _controllers_ directory. In my mind, "services" are just miniature web applications. Service _objects_ therefore should aid in responding to web requests.

Consider again our humble `CreateUser` service object. We can easily imagine how the `User.create` call inside it could have once been part of a controller action:

```ruby
class UsersController < ApplicationController
  def create
    @user = User.create(user_params)

    if @user.valid?
      UserMailer.with(user: @user).welcome_email.deliver_later
      redirect_to dashboard_path, notice: 'Welcome aboard!'
    else
      render :new
    end
  end

  private

  def user_params
    params.require(:user).permit(:first_name, :last_name, :email_address)
  end
end
```

Notice that the `#create` action creates the user, but also sends a welcome email.

As your app grows, so do your controller actions. Maybe you decide you want to register the user with your 3rd-party email/marketing system when they sign up. A few months later you decide to A/B test sending a free trial email at signup instead of the traditional welcome email:

```ruby
class UsersController < ApplicationController
  def create
    @user = User.create(user_params)

    if @user.valid?
      BrazeClient.new.register_email(@user.email_address)

      if Flipper.enabled?(:free_trial_email_at_signup, @user)
        UserMailer.with(user: @user).free_trial_email.deliver_later
      else
        UserMailer.with(user: @user).welcome_email.deliver_later
      end

      redirect_to dashboard_path, notice: 'Welcome aboard!'
    else
      render :new
    end
  end

  private

  def user_params
    params.require(:user).permit(:first_name, :last_name, :email_address)
  end
end
```

Whoa, that `#create` method is getting pretty long. More concerning though is how much logic it encapsulates - logic that can't be reused outside the controller. In addition, I've only shown a single action in this example. A complete RESTful controller will have seven.

Let's pull all that creation code into the service object instead:

```ruby
class CreateUser
  def self.call(params)
    new(params).create
  end

  def initialize(params)
    @params = params
  end

  def create
    user.tap do |u|
      if u.valid?
        send_email_address_to_braze
        send_signup_email
      end
    end
  end

  private

  def send_email_address_to_braze
    BrazeClient.new.register_email(user.email_address)
  end

  def send_signup_email
    if send_free_trial_email?
      UserMailer.with(user: user).free_trial_email.deliver_later
    else
      UserMailer.with(user: user).welcome_email.deliver_later
    end
  end

  def send_free_trial_email?
    Flipper.enabled?(:free_trial_email_at_signup, user)
  end

  def user
    @user ||= User.create(@params)
  end
end
```

I really like this. Not only is the public API minimal, I can hang a bunch of helper methods onto the class that I might have been hesitant to add to the controller.

And by extracting the user creation logic into the service object, the controller now does a whole lot less:

```ruby
class UsersController < ApplicationController
  def create
    @user = CreateUser.(user_params)

    if @user.valid?
      redirect_to dashboard_path, notice: 'Welcome aboard!'
    else
      render :new
    end
  end

  private

  def user_params
    params.require(:user).permit(:first_name, :last_name, :email_address)
  end
end
```

But skinny controllers aren't the only benefit.

### Bulk User Importer

In my mind, the most significant benefit of the service object approach is _code reuse_.

Let's say our company starts offering our services b2b and we need to create a bunch of user accounts for all the people who work at another company. We decide to add a bulk user importer to our system that's capable of reading a CSV file and creating a bunch of user accounts all at once. This exact scenario came up at one of my previous jobs.

Fortunately, our user creation logic is conveniently encapsulated into a service object, so reusing it is a piece of cake:

```ruby
require 'csv'

class UserCsvFile
  attr_reader :path

  def initialize(path)
    @path = path
  end

  def import
    table.each do |row|
      CreateUser.(row.to_h)
    end
  end

  private

  def table
    @table ||= CSV.parse(File.read(path), headers: true)
  end
end

UserCsvFile.new('/path/to/users.csv').import
```

You could copy and paste the code from the controller into the `UserCsvFile` class, [but at what cost?](https://speakerdeck.com/tenderlove/but-at-what-cost) Every time the controller changes, so does `UserCsvFile`. At some point, someone's gonna forget to update both codepaths.

### That's... all there is to it?

I'm sure some of you reading this are now thoroughly fed up. Has it really taken this guy over a thousand words just to tell you about Ruby classes?

Well, that's the thing about service objects. They really can be that simple. In fact, service objects aren't even a design pattern. They're just a code organization tool for extracting chunks of procedural code from controller actions, i.e. "do this, then do this, then do this last thing." The "service object" moniker is just a name. We could easily call these chunks of code "actions" or maybe "commands" as Jason mentions.

### Loss of Object-Orientation

In his blog post, Jason makes the following assertion:

> **Service objects throw out the fundamental advantages of object-oriented programming.**
>
> "Objects" like this aren’t abstractions of concepts in the domain model. They’re chunks of procedural code masquerading as object-oriented code.

He's absolutely right that service objects aren't abstractions of concepts in the domain model. They exist to encapsulate procedural code. After all, controller actions tend to be procedural, so it follows that service objects are as well.

This encapsulation idea is one of the tenets of object-oriented programming; the data needed to perform the action is held by the object, and the object's method's (`call` in our case) uses that data to perform the action.

### Advanced Techniques

Because service objects are just classes with basically no rules, you have the full power of the Ruby language at your disposal. Pretty much anything goes.

For example, consider the various ways our `CreateUser` operation can fail. Might be kinda nice to support some failure modes:

```ruby
class UsersController < ApplicationController
  def create
    CreateUser.(user_params) do |result|
      # creation succeeded
      result.success do |_user|
        redirect_to dashboard_path, notice: 'Welcome aboard!'
      end

      # user is invalid
      result.failure do |user|
        @user = user
        render :new
      end

      # CreateUser.() raised an error
      result.error do |e|
        Rollbar.error(e)
        flash.now[:error] = 'Something went wrong, please try again'
        render :new
      end
    end
  end

  private

  def user_params
    params.require(:user).permit(:first_name, :last_name, :email_address)
  end
end
```

Dang that's nice 🔥🔥🔥

Here's what the service object might look like:

```ruby
class CreateUser
  def self.call(params)
    new(params).create
  end

  def initialize(params)
    @params = params
  end

  def create
    if user.valid?
      send_email_address_to_braze
      send_signup_email
      Success.new(user)
    else
      Failure.new(user)
    end
  rescue Exception => e
    Error.new(e)
  end

  private

  def send_email_address_to_braze
    BrazeClient.new.register_email(user.email_address)
  end

  def send_signup_email
    if send_free_trial_email?
      UserMailer.with(user: user).free_trial_email.deliver_later
    else
      UserMailer.with(user: user).welcome_email.deliver_later
    end
  end

  def send_free_trial_email?
    Flipper.enabled?(:free_trial_email_at_signup, user)
  end

  def user
    @user ||= User.create(@params)
  end
end
```

And finally here are the result classes:

```ruby
class Result
  def initialize(args)
    @args = args
  end

  def success(&block); end
  def failure(&block); end
  def error(&block); end
end

class Success < Result
  def success(&block)
    yield *@args
  end
end

class Failure < Result
  def failure(&block)
    yield *@args
  end
end

class Error < Result
  def error(&block)
    yield *@args
  end
end
```

### Conclusion

I hope this article has explained why service objects deserve a place in your Rails app. Just remember to keep 'em out of your model code.

Disagree? [Hit me up](https://twitter.com/camertron) on Twitter.
