---
title: The Problem with Multiple Inheritance
author: cameron
published: false
---

Idea: Including a module that contains methods with the same names as methods in the host class can cause confusion for the module author(s). Eg:

```ruby
class User
  include BrazeHelpers

  def send_welcome_email
    braze_client.send_welcome_email(id, "Welcome!", ...)
  end

  private

  def braze_client
    @braze_client ||= BrazeClient.new
  end
end

module BrazeHelpers
  def send_test_email
    braze_client.send_email(id, "This is a test", ...)
  end

  private

  def braze_client
    @braze_client ||= TestBrazeClient.new
  end
end
```

It gets even worse when multiple included modules step on each other's toes.

Consider talking about the laminate gem?
