---
title: "Jakob Uszkoreit - Computer History Interview on Transformers"
author: "Jakob Uszkoreit"
interviewer: "Hansen Sue"
date: "April 24th" 
topic: "artificial_intelligence, transformers, attention_mechanism, machine_translation"
source_file: "jakob_uzkoreit_comp_history_interview.md.rtfd"
converted_at: "2025-08-29T12:00:00Z"
format: "rtfd"
converter: "elias_to_markdown"
tags: ["ai", "transformers", "google", "machine_learning", "nlp"]
summary: "Interview with Jakob Uszkoreit, co-author of 'Attention Is All You Need', discussing his path into AI, family influence in computational linguistics, and the evolution from rule-based to deep learning approaches in language processing."
---

# Jakob Uszkoreit - Computer History Interview on Transformers

**Interviewer**: Hansen Sue  
**Date**: April 24th  
**Subject**: Jakob Uszkoreit, CEO of Inceptive, Co-author of "Attention Is All You Need"

## Introduction and Background

**Hansen Sue**: I am Hansen Sue and the date is April 24th. Can you introduce yourself?

**Jakob Uszkoreit**: I'm Jakob, today I'm the CEO of Inceptive and before that I'm one of the co-authors of "Attention Is All You Need" and a bunch of other scientific publications.

**Hansen**: So can you tell us how you got into the field of artificial intelligence?

**Jakob**: In many ways that was actually something that, I guess as a problem, runs in the family. So my dad is a computational linguist who used to teach that and computer science in Germany at universities. Before that worked at SRI in Menlo Park and spent quite some time at Stanford. So in a certain sense it's something that started to enter my life over dinner conversations when I was a young child.

Then later on I started going to University in the early 2000's back in Germany again. Actually to a certain extent tried to avoid artificial intelligence/machine learning, certainly when it comes to applications around language, in order to at least stray a little bit from the family business.

Then in 2006 I stumbled upon a Google internship not too far from here and they offered me a few different research projects that I could join. Machine translation by far had the most interesting large scale machine learning problems and so with some chagrin, I bit the bullet and actually did end up in the family business of sorts.

## Evolution of Computational Linguistics

**Hansen**: When your father was working in computational linguistics, what were the techniques then and how would you contrast the techniques that he was using versus the techniques that you were using?

**Jakob**: In those days in computational linguistics, the techniques were still - they were becoming more data driven. There was more machine learning being applied at least in certain specific parts of larger systems, but there were still certainly heavily informed by and often times really driven by linguistic insights. In a certain sense, in the broadest sense, theory of language or theories of language that were used as, again, in the at least underpinnings in how those systems were designed, but often times really were used as the backbone of how they actually operated.

In stark contrast, right, what we started doing already in 2006 and then 2004, 2005, 2006 at places like Google Translate was much less informed by basically our conceptualized understanding of language or a conceptualized approximation of an understanding of language and was trying to be more black box. Yet at the same time often still constrained by, say, combinatorial optimization algorithms that made assumptions - strong assumptions - about how often times the outputs of such systems such as Google Translate would be assembled as functions of the input.

So for example, at the time, the leading approach was statistical phrase-based machine translation where you make the assumption that you can chop the input sentence or input string into phrases, each of which have a small number of candidate translations. And then what you're actually doing is within a certain search cone, so to speak, you're allowing yourself to reorder those - not embracing the full combinatorial explosion of all possible reorderings, but you're allowing a limited amount of reordering and choice among those phrases.

But that means you're still making a strong assumption when it comes to basically how the equivalence can be expressed between two sentences in two different languages.

What happened then with basically the Renaissance or resurgence of deep learning and applying that increasingly to language was really to, in many ways, reduce the assumptions or limit the assumptions that had to be made about any such correspondences to an absolute minimum and treat it really as a black box problem.

## Timeline and Transition

**Hansen**: So then the time that you were describing your father working on it, what era was that, what years were those?

**Jakob**: Those were basically 80s, 90s, and then the 2000s. And the 2000s I guess was when really the transition happened from systems that were largely rule-based, largely based on again [continues...]

---

*Note: This is a partial conversion from the original RTFD file. The interview continues with discussions about the development of neural networks, the Transformer architecture, and the "Attention Is All You Need" paper that revolutionized natural language processing.*