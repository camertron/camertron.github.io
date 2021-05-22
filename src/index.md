---
layout: home
---

{: .mb-5 .title}
👋 Hey! I'm Cameron.

I'm a software engineer with 10+ years of experience interested in pushing Ruby and Rails forward.

----
{: .my-6}

# Latest Articles
{: .mb-5 .title}

{% assign posts = site.posts | slice: 0, 6 %}
{% render "bulmatown/collection", collection: posts, metadata: site.metadata %}

{% if site.posts.size > 6 %}
  <a href="/posts/" class="button is-primary is-outlined is-small"><span>Previous Articles</span> <span class="icon"><i class="fa fa-arrow-right"></i></span></a>
  {: .mt-6 .has-text-centered}
{% endif %}
