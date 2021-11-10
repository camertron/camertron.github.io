---
layout: post
title: "Some Thoughts on Technical Debt"
date: 2021-11-09 20:53:00 -0800
author: cameron
published: true
---

My thoughts on a ["recent episode of the Compiler podcast"](https://www.redhat.com/en/compiler-podcast/what-is-technical-debt) entitled "Do We Want a World Without Technical Debt?"

<hr>

I’m a big fan of pretty much everything Saron Yitbarek does, and recently one of those things has been the excellent [Command Line Heroes](https://www.redhat.com/en/command-line-heroes) podcast. The most recent show was actually promoting another podcast called Compiler, specifically their fourth episode entitled [“Do We Want a World Without Technical Debt?”](https://www.redhat.com/en/compiler-podcast/what-is-technical-debt).

This was a really thought-provoking episode. I found myself trying to add my opinion out loud while on my daily walk with my daughter. Considering she’s only two and couldn’t hear the audio, the conversation was fairly one-sided. Fortunately at the end of the episode, hosts Angela Andrews and Brent Simoneaux ask their audience to weigh in. This post is an attempt to write down my thoughts.

## What is Technical Debt?
In my experience, technical debt is the cost of choosing a faster, easier, or partially complete solution over a more thoughtful, time-consuming, or correct one. Most of the time these decisions are made because of time constraints. “We need this feature yesterday!"

Anyone who’s worked for a few years in the software industry has likely encountered these opposing forces of time and correctness. Given infinite time, theoretically a software development team could produce a completely correct and consistent system. The problem of course is that infinite time - or even sufficient time - is often not available. In these situations, software development teams frequently choose to incur technical debt, producing a system that works /well enough/ for the given set of requirements. The idea is that, at some future time, they’ll revisit the problem and implement a more robust solution.

Sounds like a fair tradeoff, right?

## When Tech Debt Accumulates
Unfortunately in my experience, paying down tech debt only rarely happens in practice. It’s not difficult to understand why. Many teams find it challenging to justify revisiting a feature that’s already working for customers. In addition, software development teams are always under pressure to fix bugs and ship new features, which means they often prioritize those things over less glamorous tasks like reducing debt.

As you might imagine, ignoring tech debt and over again can lead to a large accumulation of it. Software is built on other software, meaning that hastily written code not only adds tech debt of its own but has the potential to affect any of the code written on top of it as well. Even in small systems, failure to address tech debt in a timely manner can gradually and perniciously slow down development, leaving the team with increasingly less capacity even though the size of the team itself hasn’t changed.

## So is Debt Bad Then?
I realize I just made tech debt sound like a bad thing.

As you might have noticed, conversations about debt - tech debt included - are usually framed in the negative as if debt is this horrible thing we should avoid. The truth is, debt is an extremely important and useful tool. Let’s examine how it works in its native environment: the financial world.

The general public is probably most familiar with the sort of debt that comes with using a credit card or buying a house or car. It’s probably not a stretch to say that most people don’t have $25k lying around at any given point to drop on a car. Instead, they finance the purchase by getting an auto loan. They make monthly payments on that loan until the lender has received back the full amount. In this scenario, everybody wins. The lender makes money by charging interest, and the buyer gets to drive away in a new car even though they can’t afford the full purchase price up front. Such a transaction would have been impossible without debt.

Financial institutions, governments, and businesses use debt all the time. The US government for example issues bonds, which are sort of “reverse” loans where individual people loan money to the government. Venture capital firms loan money to start-ups they hope will take off and make them large returns. You can even see debt at work between whole countries.

-The thing is, debt isn’t just an amount of money you owe to another person or institution - it also establishes your credibility. Banks, companies, etc are more likely to lend to you if you’ve already shown you’re a trustworthy borrower. Missing or late payments, default, etc can damage your reputation.-

## Tech Debt Through the Financial Lens
For whatever reason, I haven’t heard very many programmers talk about why  “technical debt” contains the word “debt.” It’s a curious choice of words, but really very appropriate.

Imagine for a minute that every decision you make as a programmer is a financial transaction. Our currency is time. Decisions that don’t require trading large amounts of time for correctness are simple, direct transactions. Decisions in which you sacrifice correctness in the interest of time are /loans/. The loan represents time borrowed from the bank - time you promise to repay later. At the risk of stretching the metaphor a little too far, we might even say the bank collects interest since it always takes more time to dive back into code you wrote a while ago.

Again, everybody wins. With their borrowed time the team can deliver systems and features faster. The bank will eventually get its time back plus interest.

I like this parallel to the financial world because it makes it more obvious why it’s dangerous to ignore tech debt. Taking on too much financial debt can lead to monthly payments you can’t afford. Miss too many payments, and the bank will repossess (take back) your car. Taking on too much tech debt can have a similar effect. Instead of working on a new feature, you might be forced to spend all your available time dealing with flaky test suites, awkward database relationships, and production emergencies.

If tech debt can cause such headaches, let’s ask the obvious next question: is it possible to get rid of it entirely?

## Tech Debt is Unavoidable
Unfortunately, no.

The most successful teams I’ve seen that manage their tech debt effectively do so by including it in their planning. They track it in their software management system and discuss how much time should be allocated to reducing it every sprint. Sometimes, an entire sprint is dedicated to refactoring a certain part of the code to make it easier to implement a new feature the /following/ sprint.

However, tech debt accumulates even in systems nobody’s working on.

If you’ve ever tried to dust off and boot up an old app, you’ve likely run into the phenomenon of /bitrot/. Code (almost literally) /rots/ as it ages. Bitrot happens because our apps are made up of so much more than just our own code. They depend on a bunch of other software packages, build tooling, CI pipelines, 3rd-party APIs, and external systems. A software package that built successfully on your laptop with Clang 3.5 in 2014 now dumps out a whole mess of compiler warnings and an esoteric error message. The version of the 3rd party API your app relies on was deprecated in 2015 and removed in 2016. The latest version of MySQL no longer supports a specific type of column your app relies on. The list goes on and on.

While it’s true that, in actively maintained systems bitrot is less likely, such systems are still susceptible to forces outside of your control. The canonical example is probably upgrading to the next version of your app’s web framework. You want all the new features, bug fixes, and security patches in the new version, but the upgrade isn’t going to happen without a serious investment of time and effort. In my experience these upgrades can sometimes take years to pull off.

New framework or library versions are an example of passive tech debt. Similar to bitrot, passive debt accumulates by no fault of your own. New versions signal that the framework and community are moving on without you. In fact, there will always be new versions of this lib or that, new technologies and new approaches for solving problems. Unless you’re upgrading on a regular schedule, this sort of issue can become a real thorn in your side. For example, it can be hard to attract talent to work with outdated technologies and tech stacks. Older libraries often don’t receive security patches either, meaning you’ll be on the hook for fixing them if vulnerabilities are found.

## Embracing Tech Debt
It’s not all bad news though. Tech debt might be unavoidable, but that doesn’t mean it can’t be effectively managed. In fact, I would argue that any team making good progress on a software project must be taking on debt.

That’s because software is almost never written correctly the first time around. It often takes a number of refactorings, real-world usages, and mental model shifts before a piece of software settles into its final shape. Considering this, there’s no reason to spend time worrying about the correctness of your code, at least at first. It’s going to change, perhaps drastically, during the next iteration anyway. Rather than spending lots of precious time worrying about code correctness, focus on getting something out the door.

Frame the tech debt conversation in terms of the inevitability of bad code. In my opinion, there’s no such thing as “bad” code running in production anyway. If it’s making you money, it probably isn’t bad. With that mindset, debt becomes the sort of tool it is in the financial sector. Let it free you from worrying about writing flawless code, and from the negative connotations associated with the word “debt.”

Happy hacking :)
