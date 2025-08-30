---
title: "TXT"
source_file: "TXT.rtf"
converted_at: "2025-08-29T01:33:46.102204Z"
format: "rtf"
converter: "elias_multi_format_text_converter"
---

I am Hansen Sue and the date is April 24th M and can you introduce yourself uh
I'm Jakob today I'm the CEO of inceptive and before that I'm one of the
co-authors of attention is all you need and a bunch of other scientific Publications thank you um so can you
tell us how you got into the field of artificial intelligence in many ways that was
actually something that uh I guess as a problem runs in the family so my dad is
a computational linguist uh used to teach that that and computer science uh
in Germany and universities um before that worked at SRI in Meno Park and uh
spent quite some time in Stanford and so in a certain sense it's something that um yeah started to enter my life over
dinner conversations when I was a young child and uh then later on I uh started
to going to University in uh the early O's uh back in Germany again um actually
to a certain extent tried to avoid uh artificial intelligence SL
machine learning certainly when it comes to Applications around language uh in order to you know at least stray a
little bit from uh from the family business um and then in 2006 I stumbled
Upon A Google internship uh not too far from here and they offered me a few different research projects that I could
join um and machine translation by far had the most interesting large scale
machine learning problems and so with some chrin uh I bit the bullet
and actually did end up in the family business of sorts interesting so when your father was working uh in
computational linguistics um what were the techniques then and how would you contrast you know
the techniques that he was using versus the techniques that you were using so in those days in computational
computational linguistics the techniques were still they were becoming more data
driven um there was more more machine learning being applied at least in certain specific parts of larger systems
but there were still certainly heavily informed by and often times really driven by uh linguistic
insights in a certain sense in the broadest sense theory of language or theories of language that were used as
again in the at least underpinnings in how those systems were designed but often times really were used as the
backbone of of how they actually operated um in stark contrast uh right
what we started doing already in 2006 and then we 2004 2005 2006 uh at places
like Google translate was um much less informed by basically our conceptualized
understanding of language or a conceptualized approximation of an understanding of language and was trying
to be more black box yet at the same time um often still constrained by um
say combinatorial optimization Al algorithms that made assumptions strong assump iions about how uh often times
the outputs of such systems such as Google translate would be assembled uh as functions of the input and so for
example at the time um the leading approach was statistical phrase-based machine translation where you make the
assumption that you can chop the input sentence or input string into phrases
each of which have a small number of candidate translations and then what you're actually doing is within a
certain search cones so to speak you're allowing yourself to reorder those not embracing the full comunal explosion of
all possible reorderings but you're allowing you know limited amount of reordering and choice among those
phrases but that means you're still making a strong assumption um when it comes to basically what the how the
equivalence uh can be expressed between uh two sentences in two different
languages um what happened then with basically the the Renaissance or
Resurgence of De learning uh and applying that increasingly to language was really to in many ways reduce the
reduce the assumptions or or limit the assumptions that had to be made about
any such correspondences to an absolute minimum and treat really as a blackbox
problem right so then the the time that you were describing your father working
on it what era was what years were those I mean those were basically uh 80s '90s
and then the O's and and the O's I guess was when really the transition happened
from systems that were largely rule-based largely based on again
conceptual uh conceptualized theories if you wish understandings of of phenomena
like language uh towards things that were at least where at least you had
larger numbers of parameters that were estimated using machine learning methods um and where the the constraints were
still informed in a certain sense by linguistic understanding uh but not anymore uh basically forming the the the
actual backbone of those systems but yeah those were basically those three decades where that shift happened or
over which of the course of which that shift also happened so there's been over the three decades there's been a
progression an increasing progression towards removing linguistic Knowledge from the machine learning systems
removing it from the machine learning systems or maybe from the perspective of some of the practitioners at the time
moving it into from the from the actual implementation and the algorithms um
into uh constraints on statistical models that were then used to capture
those phenomena uh but I would say also in a certain sense weakened right so so
making making fewer or B ing it less on on ultimately theory if you wish yeah
that's right okay um so uh
in uh so I read that like around 2012 um one of the one of the um so wait so when
you first started um in 2006 you were were you immediately put on Google
translate or yeah that's right okay yeah and then by 2012 what were you working on at that point
by 2012 I had actually recently transitioned out of Google translate and into a new team that um at the time
internally was called aqua uh that we had dubbed Aqua um didn't stand for
anything in particular but what it was really is the language understanding team of the product that later became uh
known as the Google Assistant it wasn't called that yet uh neither internally nor externally um but had basically
basically started working on systems that effectively by in the broadest
sense semantically parsing queries would enable Google search especially on
mobile especially in certain interfaces um to uh use a if you wish deeper
understanding and more explicit formalization of an understanding of a query um that may have been formulated
more in natural language than you know in Google e as as as we would call uh in order to immediately give answers
or uh execute actions that the user may have uh may have desired M and was that
motivated by comp competition that's right that that's right so basically that was motivated ultimately by by
Apple Siri um and the uh the concerns
that or the concern that Siri could change the way people expect to search
and uh and obtain answers but also execute actions um in particular through
uh when when when dealing with their mobile devices MH and what were the limits of the
technology at the time
um I would say I mean compared to what we're able to do today it was incredibly
limited um and one of the issues was that the statistical methods so we were
still applying methods that were if few squinted very reminiscent of statistical
machine translation systems um and what that implied was that we actually had to
fabricate training data that was remarkably similar um all the way to
say what type of question was being asked or what precise action was uh uh
was was requested of a device to schedule a timer or or an alarm or some such um and we had to gather quite a bit
of training data uh from humans uh or or fabricate training data using uh using
humans um that that was remarkably similar to what we would actually expect to see in the query stream um and we
were only to an extremely limited extent able to use very large amounts of
language in different domains and of different uh types uh in in improving
our understanding of of queries and you know from from such a distribution and so really we couldn't really bring to
bear say uh you know the majority of the web or so right it basically was all
purpose built manufactured in fact we we used uh at the time um large numbers of
uh what I guess we would now or one would maybe call gig workers in order to
uh to fabricate that training data because there basically was no such data there was no data in existence that was
sufficiently similar to what we expected that query stream to look look like and um so can you describe to a uh
someone of a high school level um what is an RNN and an lstm and explain the
full acronym okay so rnns are recurrent neural networks lstms are long
short-term memory recurrent neural networks um basically what they do is
they evolve in step that are taken in a recurrent fashion
we'll get to that in a second they evolve a vector space representation of some something that is
seen as a sequence of elements and so let's say in language the sequence of
elements could be sequences of words each of those words is represented by a
vector at first it could be something uh like an indicator Vector that you know for any word in your dictionary has
exactly one dimension and there that Vector has the value one and has zeros elsewhere um but then that Vector is
mapped through a lookup table if you wish onto some Vector in some higher dimensional space so now we have a
sequence not of words anymore but vectors and some higher dimensional uh space of of of real numbers um and this
RNN now evolves a representation of that entire sequence um or basically series of
prefixes of that entire sequence by mapping the next or that the current
Vector that it is the current word Vector that it is consuming uh through some uh
mathematical mapping and then merging that into an
existing uh State vector and so you have some State Vector that starts with some
initialization initial value and now in every step you basically take in uh a
new word Vector in the case of a sequence of words you send that through some mapping and then um either in in
the course of doing that mapping or with a separate mapping you now merge that into basically added with some waiting
uh into your current state and then you proceed to the next word vector and again add that into your current state
and you also at every given step potentially transform your state in a in a way that is independent of uh of the
next word Vector now in lstms what you do is you actually lstms
are a special version of all of these mappings basically the mappings that uh
control how you integrate the next word Vector how you integrate the previous
state Vector um and uh with with some additional bells and whistles around the
ability to basically in a certain sense forget your previous State as a function of the new word um to retain a certain
amount of the previous state to ignore the current word as a function of your state and as a function of the new word
and so on and so forth and so basically it uh allows you uh it allows the model
uh how should I say um a sharp control uh to a certain extent to learn to
control sharply um how much of these various um state or new word vectors to
use in the computation of the subsequent State Vector
okay if that makes sense I'm not sure I fully got that but that's okay well we'll move on okay um so talk about what
led to the invention of the Transformer and what was the key Insight okay so
um ultimately uh the the situation we found ourselves in at the time was that
that these recurrent neural networks um that again coming back basically had
to evolve some kind of state vector or some kind of state representation over
the course of uh of you know some sequence of vectors such as vectors
representing words um that that when training those models on very large
amounts of data uh as you would find in some problems uh say in Google
search you would actually never reach the performance uh of much simpler neural
network models um trained on the same data and the reason was that these much simpler neural networks trained orders
of magnitude faster and so even though they were much less expressive uh say for example simplistic
feedforward neural networks um uh multi-layer perceptrons for
instance that you could easily show were not not as expressive as rnns or
lstms um because for example they couldn't actually iterate through these sequences they had to chop those
sequences into engrams and then map those onto vectors and just add those basically forgetting about the global
ordering of them and so on and so forth they couldn't be that expressive but because they were training so much
faster you could actually uh they would actually see much more orders of
magnitude more training data uh in any given amount of time than say an RNN or an lstm and would as a result still
perform better in practice then these much more expressive models that we knew could actually handle language in a much
more holistic manner or phenomena in language such as longdistance dependencies in in a much more holistic
and and much more appropriate Manner and so at the end of the day and this this
wasn't true for all problems at the time this was really pronounced only in cases
where um you really were able to generate massive amounts of training
data such as for dealing with queries in in the regular web search query stream
of the regular web search query stream uh at Google and it also it it
basically made it clear that if we could find a way of making such feed forward
models train much faster on whatever Hardware we had we could potentially
actually get the best of both worlds right if we could make them oh sorry if we if we uh I think that that came out
wrong I think if we found a way of making these feedforward models more expressive akin to rnms or lstms yet
uh somehow retain their fast training speed that we would actually get the best of both worlds basically have
something have models that could really be expressive enough to capture language
as a phenomenon fully or holistically while also benefiting from these vast
amounts of training data that that we were able to manufacture and one of the fundamental insights from
a linguistic perspective or just from a statistical perspective this doesn't just apply to language this applies to
to many different signal types uh one could argue all signal types that we can make any sense of in fact one maybe
philosophical Insight here is that this must be POS possible by exploiting the fact
that there are hierarchical there is a hierarchical nature to at least our
understanding of pretty much every stimulus that we get meaning we
basically um in in language for example right if if you uh in in in grade school
or later High School you you parse sentences right what you're really doing is you're expressing the fact that there
is hierarchical substructure where you have individual phrases that basically where you can in a certain
sense arrive at some understanding of in quotes most of their meaning just looking at that phrase and then maybe
you have a different another phrase in that in a sentence where the same is true and then the third one and now in
another past you don't actually need to go through every single word anymore in sequence you can aggregate these what
what you've basically already in isolation determined as the meaning of these individual phrases and put those
together to the meaning of a bigger phrase and so on and so forth now why is is that Insight interesting
it's interesting because the hardware that we had at the time is actually still remarkably similar to the accelerator Hardware that's being used
in deep learning today excels at parallel processing and so if you're able to identify what are some of these
chunks that you can in isolation uh make some sense of already without looking at everything then
you've just enabled parallel processing so basically you've said okay fine then we look at this phrase this phrase this
phrase in isolation get to some extent an understanding of what they mean some Vector space representation of what they
mean and then in the next step we don't only need to actually aggregate those basically representations and so on and
so forth and that's in direct contrast to
what rnn's do right because they they walk through the entire signal step by step one after the other and they have
to do that in order to then arrive at some state representation in the very end after having run through that entire
signal and so basically um what motivated these uh then self
attentional models was this Insight that by basically paying what looks like a
performance penalty initially namely by having every piece of the signal interact but in a very shallow way with
every other piece of the signal that doing that would enable it to actually in a certain sense build soft tree
structures over your entire signal that would then ultimately exploit the
ability of these accelerators to do parallel Computing as opposed to sequential Computing so you basically
parallel compute the interactions between all pieces of the signal or every piece of the signal with every
other piece pairwise if you wish and then you would just repeat that step and it turns out that you don't need to
repeat that um nearly as many times as the signal is long and that is
ultimately what makes this type of parallel processing way faster Master on Hardware that is very good at performing
these this large number of but more simple kind of pairwise comparisons in
contrast to uh you know a sequence length many or sequence length many
harder operations if you wish uh that then tried to basically keep that Global State up to date at every given at every
given step okay so it sounds like in computational terms
you have you're going from a linear algorithm to something that logarithmic
logarith exactly that's exactly right okay but but you can't directly you don't know the tree and so as a result
you can't directly and this is what you know what if if we knew the tree or if there was really truly a tree I don't
believe there truly is a tree right because because it's only approximately correct that these signals are Tre structured or truly hierarchical but if
we knew a tree and if it existed we would just draw the tree and then we would basically just aggregate the the
individual representations along that tree and then we would actually end up at something that is logarithmic if we
process it in parallel right because we only need logarithmic many steps in terms of tree depth in order to actually
process the signal of a given length they don't know the tree and so as a result how do you
approximate the tree you don't know which basically branches let's assume it's a binary tree so at every given
level two things are paired up we don't know what that tree looks like okay seems silly but why don't we iterate
over all possible pairings and now this at first looks counterintuitive uh from
a computational efficiency perspective but if you make that very simple and in case of these self attentional models
what usually this operation looks like is just um an inner product if you make that really simple then you can do many
of these inner products in parallel there's no sequential dependency whatsoever that's what these accelerators love and then effectively
have iterated over all possible branchings at that level and then you take another step and you iterate over
all possible branchings again and again and so basically for if you happen to
have Hardware that looks like these accelerators like gpus tpus Etc um then that is a much better allocation of
compute than requiring it to be more complex basically matrix multiplication steps many few or so per step but then
times the length of the system overall uh length of the signal overall I see um so what is self-
attention and how does it work self attention is a way of imbuing feed
forward models models that are that don't require recurrent steps um along
the length of a signal with a um effectively Global
receptive field with a way of looking at or of considering
all possible pieces of an input signal at any given moment at any given step
and so the way uh in the Transformer and in its its its predecessors decomposable
tension model uh Etc that we published before the way that worked was by
effectively doing pairwise comparisons uh exactly like I just explained right so instead
of um instead of aggregating a certain kind of state by doing uh a set of
Matrix multiplications for each new element and doing that in order you now
basically process uh you compare um every single pair uh of representations
that gives you a waiting of uh for any given element of all other elements
so if we want to go into more detail here what you do is you these pairwise comparisons give you scalers for each
pair of representations in fact Maybe even for every given position they give
you a scaler for every other position now you could normalize those into some something that sums up to one you can
call that a distribution over all other positions and now you can just add those up weighted by exactly that distribution
um and so in a certain sense you can conceptualize this as for every given
position in your signal let's say it's a word you're getting at every given step
a waiting of all other words and you could say even though that's taking it a little bit too far um but but slightly
oversimplifying you could say that tells you how important at this moment each of these other words is for
determining the meaning of that word then you basically aggregate those in an
operation that is totally simplistic you just add them up and then you send that through one basically feed forward
through a small MLP but that small M MLP now operates only on this aggregation so
you basically what's an MLP uh multi-layer perceptron so a very simple feed forward Network again no no
recurence uh uh you know no iterative process basically you just you you you
have this very simplistic addition that is in a certain sense independent of it's not truly independent of the length
of the signal right but it's it's very very simple you can apply it to to very large signals and then you just end up
with one vector again and that you send through uh uh through through this simple uh multi layer perceptron uh in
fact usually a pretty small one and you do that again in parallel independently for each of your positions for each of
your words so in every step what you do is for each word you attend to every
other word meaning you get a distribution over all the other words weighted by that distribution you sum
them all up so say if if you want something that looks like a tree then then your distribution is very pequ only
on one other word and it's almost zero for all the others right and and so that now means you're just getting the vector
from just that one other word you add it to your own you send that through uh
your your um feed forward Network through your multi-layer perceptron and
that then forms the representation for the word in question that we're talking about in the next layer and that's the
process that gets repeated layer after layer but in every layer you do it not just for one word but for all of them in
parallel but they're all independent right because you you don't need to know
the new representation of any other word in order to compute your new representation and that is what again
shapes the workload into something that is much more manageable and much more
efficient ultimately uh on today's very parallel accelerator H hardar okay
um so uh could you maybe um Define um because
I'm not sure the audience understands the difference um Define recurrent and feed forward okay
so basically a recurrent neural network um process processes uh a given signal
in a fashion uh that is iterative so it steps through every element of that signal and if that signal is
say a sentence as it would be commonly represented then for every word in it every token um uh you have one vector
and you now basically process the first vector and then you get a state then you somehow process the next word vector and
your state and you integrate them into some new state and you keep doing that problem with that is it takes you at the
very least as many steps as your sentence is long a feed forward uh um neural network
or um MLP basically takes some fixed length
input and sends that through a series of such Transformations the same that you
apply as you recur through your signal in a recurrent neural network very similar but only in a um in a fashion
that that is uh that only applies to one fixed length um and hence also has a a
fixed number of operations now that means if you want to process signals of
variable size with something that is feed forward you TR additionally had to
somehow aggregate that into something of fixed size and the way that would often times
happen is by just saying okay if we take our sentence with a word Vector per word
and now we have moving Windows of say three words or so and we basically for
each of these moving for each of the three words under this moving window we map them onto one vector and then we just add them all now we have one vector
and that we can send through a feedforward uh um structure Network structure
um if you wish but now you've lost all ordering information right and so what what self
attention coming back to uh to what we talked about before it does is it gives you a way of processing something of
variable size uh despite the fact that what you're doing is you're just applying
feedforward elements there's an important detail which I for which I
which which I didn't mention so far um uh which is that
in the way I just described self attention you would have still forgotten the ordering in order to retain the
ordering you need to basically Infuse each word Vector with some
representation of where the word was in in the signal in the sentence um but
once you have that you can actually retain the ordering um in a way that uh
is not recurrent that doesn't require you to do a number of steps that is a function of the length of of your signal
okay um so why did you call it a Transformer um and who came up with the
name um so why do we call it a Transformer um ultimately it makes a lot
of sense if you think about this kind of holistic transformation of the entirety
of the signal in every step right uh in contrast to recurrent neural networks
that evolve a representation over yeah as they occur as they iterate over a
signal right this thing basically has some representation of the whole thing and transforms it in whole You could
argue it is that that difference isn't you know maybe that that that what rard
neural networks do also is a transformation it certainly is but up to that point nobody else had used the name
it seemed to be pretty fitting um I had some uh some Transformer toys when I was a kid that I really liked uh I came up
with the name um but it was uh you know there was some tongue and
cheek um Swagger if you wish uh in the choice of the name too um so it was you
know we we I would say Among Us still even Among
Us somewhat secretly but we did have high hopes for this to maybe also be transformational
but interesting um can you talk about
coming to assemble the team that um came together on this paper so
the team came together in a bunch of different waves if you wish and and
those waves were by no means um planned or or uh
orchestrated what happened was that um Ilia pushin uh who was uh running a team
uh a part of my team at the time um in Google research um had decided to leave
the company and so he but he had he had several months
uh during which uh as far as I recall he was waiting for his co-founder to be
able to um leave behind what he was doing at the moment although I'm not 100% certain
about that anymore but basically there were a few months uh that he was still going to spend at Google but he knew and
we knew that he was going to leave after that and so his appetite for risk um
Skyrocket effectively compared to what he was doing before before he was managing a larger sub team of mine and
they had some pretty clear engagements um and uh with with search with with
product teams and so once his transition out began he basically was uh yeah with
a much increased appetite for risk looking for something crazy to do and this is in the context of a group
that had just published um a paper on a model called decomposable attention model that was
also a fully self attentional model um the the first one we believe uh of that
kind and we were playing with self attention mechanisms in a bunch of different applications and in a bunch of different shapes and forms was that the
first publication of attention at all no uh so attention actually uh not in the
self attention manner was applied in sequence to sequence or seek to seek RNN
LST models routinely at the time okay um so you would basically the mechanism that I described where for any given
word you get a distribution over the other words you would do that but for every given word you would get a distribution over say for every given
output word in the translation system you would get a distribution over input words and so that mechanism attending
from one signal into another was being used routinely was part of the state-of-the-art and machine translation
at the time uh there were there was another group in Edinburgh actually that was also looking at a self- attention
mechanism in order to improve rnns so they're basically as an RNN would
generate output they would attend to the previously generated output um but aside
from that work we believe uh we were actually the the first to publish back in 2016 uh on self
attention and now that publication actually we were working on that already
in 2015 uh and and before just took us a while to get around writing up a small
short paper for emlp publish that there but basically that was the context of a group so we we we had already applied
mechanisms like that although implemented in a much less scalable way to be clear to a bunch of different
types of signals including language but on on much smaller tasks than large scale machine translation and uh you
know I had high hopes for basically replacing recurent neural networks
Wholesale in seekto seek style models uh that were applied to say all sorts of
things from uh machine translation to Gmail autocomplete and and lots of other
problems um at the time and so you know Ilia said why not sounds crazy but uh
that could actually work um he was also quite hopeful that there would be practical applications also for his soon
to be former team uh because it could potentially speed up question answering
models that they had been working on in Google search where latency requirements were actually uh uh very very tight and very quickly
asish vasani who was at brinan at the time was also looking for something new to do he had worked on a few different
projects but uh you know nothing really with the potential uh at least that he
was looking for uh he was also looking for something new um they had talked I talked to sh around the time that that
he started a whole bunch and so uh they started hacking away on this and and
we wrote up some initial design doc uh that basically just said we're going to apply this to all sorts of different
problems iterative self attention uh for all sorts of different problems including machine translation um and
then we had a meme there of a bunch of Transformers zapping lasers and uh and they got going on on actually trying it
out um and actually and now I don't remember the exact sequence of events at
some point in time Nikki uh parar who was also uh on my team at the time uh
joined forces and started running experiments and we saw first signs of life but also saw those to Plateau after
some time and that's not uncommon in in uh in these kinds of efforts because
turns out that even if your intuitive or conceptual idea for a mechanism is has
lots of promise or holds lots of promise you really need to get all the implementation right you need to really
optimize it because a lot has to do everything has to do with computational efficiency and we hadn't we were
building Bas we I shouldn't say we actually it was really a shish and and Ilia uh were were and Nikki they were
building this codebase from scratch as a new research codebase uh it didn't they simply didn't have time hadn't had time
to implement all the bells and whistles of what then was basically super fast
moving modern day deep learning um and and around that time when we joined
through happen stance ultimately um some folks in the brain team no shazir lukash
Kaiser and Aiden Gomez um uh saw what we were doing there and
decided to uh experiment with the self- attention mechanism in a code base that they had been building uh at the time
actually in order to build convolutional seekto seek models uh so so a different
attempt of moving away from recurrent models in seek to seek um but but based
on on convolutions and uh they then added the self attention mechanism to it and it really improved their results and
they had a code base that actually had all the bells and whistles and uh then
uh came a crazy period of time when uh basically Noam and and no Lucas and
Aiden um ripped out what they had put in the other mechanisms that they had put
in before and in the end we're left with something that was purely self- intentional it looked lot like the
architecture that asish had and Ilia Ilia had left the company by now but that asish had put together or that
asish had at the time but it was now implemented in this other framework uh with all the the black magic tricks and
uh and in a way uh that really you know Noam who's one of the most legendary
deep learning magicians uh there are uh right he he then ultimately also
implemented that mechanism in it very very efficient way and so what
started then was actually the end of that plateau and that turned into just rapid improvements in performance of
these models for basically almost every day for months and uh yeah was just an
incredible uh incredible ride so there's very interesting thing that you just
talked about which is that um the Insight that that was
discovered was was that by taking out these things um these quote bells and
whistles that you mentioned well the bells and whistles were important in terms of training tricks etc etc um but
it was other mechanisms convolutional mechanisms etc etc those were the ones that that we removed and that's would
actually you know reduced it back to this very pure self- attentional architecture that then also worked really well once in that other code base
that had all the the tricks of the trade if that makes sense so we took out
architectures but it now was implemented very efficiently by Noah in this code
base that had all the tricks of the trade so basically the differentiation here is the the tricks of the trade the
the Deep learning black magic that was crucial to have but what they had had before was something that had some
convolutions and some other stuff and you know and then they had added the self- attention mechanism on top of that
and what they then did was remove all the other stuff they had had before they added self attention being left with just self attention but now newly
implemented super efficiently in this code base that had all the tricks of the trade all the Blackmagic uh Wizardry um
and that's really what then in a certain sense really started to show not just promise
but started to just improve rapidly and very quickly Way Beyond the state-of-the-art okay
so okay yeah so so that so that means like you it kind of went back to a pure
self attention model exactly exactly exactly um so by by tricks of the trade the black magic you mentioned like is
this sort of like um like I've I so I've read that like designing neural networks
is is in a way more of an art than a science is that that's correct that's right so basically let me give you a few examples
so um there are things like what was called layer normalization or layer Norm
at the time this is a at Best turistic Way statistically motivated in in some
sense but but really at best turistic way of making sure that none of your
activations uh go through the roof um and just in terms of their absolute magnitude which then makes optimization
incredibly challenging and the way you implement that actually makes a difference you can
Implement a bunch of different different ways in fact one could argue the very first Transformer paper had it in a weird way in a funky way but but but an
in effective one um but but you basically need to have fast and uh
working verified implementations of such a trick if you wish uh if you want your
architecture to really behave optimally another one is label smoothing where you
don't actually train your model to predict the very pequ empirical
distribution of it is exactly that next word that will follow these previous words and so basically all other words
are zero probability and that word has all the probability Mass but it turns out it's easier to train these things
and you get in a certain sense maybe more robust parameters more robust Solutions in the end if you smooth that
distribution a little bit and you actually allocate reallocate some probability Mass to the words that you don't actually observe and take it away
from the word that you do observe in your training data that you train your model towards why we could talk about with a length and nobody really actually
knows and so it's basically tricks like that that you not only have to have but you need to know how to use them you
need to they're kind of these magic constants that some folks such as Noom for example they just have a feel for it
they've done it a million times they know okay yeah label smoothing with this kind of um uh parameter or here is how
you apply layer norm and here's how you implement it well and that list of such tricks is pretty long and so you you
need to have those in order for your say new architecture to even in C in a
certain sense stand a chance right your your conceptual mechanism can be as good as it wants it needs to be implemented
super efficiently and you need to have overall a setup in which you have these tricks of the trade at your disposal
because not all of them are going to be useful for all versions of all architectures right that you need to
start experimenting with those and playing around with it and then you look at how your models perform and how they
react to some of these tricks and then Alchemy and then you add some others and
then you modify them a little bit right in that kind of tinkering that is really this kind of this kind of art and to
drive that point home maybe it's now been over six years and you still have
you still find in open source open source competitive open source code bases implementations of the
Transformers that use some of the same magic numbers that the original paper had right so there really there clearly
is some art to this right uh and and uh you need
ultimately the art at least as much if not more then you
need these conceptual insights of hey wouldn't it be more effective if we did this pairwise comparison even though it
looks kind of silly but then iterate that only a few times in contrast to
iterating over the signal purely sequentially right um
yeah um so how did the how did the name of the paper come to
be to tell you the truth I don't remember okay so there's the the the
story um Leon uh who also joined the project
actually uh somewhere around the time that Nikki joined uh a little bit later
as far as I recall um he at some point
recalls he he recalls at some point suggesting this as a relation in
relation uh uh you know well first of all making it clear and emphasizing that
we're really going against the grain and propos a new well it wasn't entirely new
the mechanism at the time right but we we had published on it before but uh to to take this new mechanism and really
dump everything else out and just build with that and that that rapid departure from uh basically all other established
mechanisms was something that we should emphasize and do so in a in a in a uh
you know in a strong way but also this nod to The Beatles um and I may not
actually have been in that meeting although I thought I was but yeah basically at some point uh uh he
proposed that uh you know isn't aren't we actually saying that attention is all you need and that stuck but but yeah
again I don't remember any of the any of the details actually okay so it's a reference to the beetle song it's also a
reference to The Beatles song but it's also it it also certainly as far as I recall it was the way he said it at the
time was probably also driven by this kind of uh in a certain sense defiant
phrasing of ah we don't need all that stuff blah blah blah is all you need right uh that that you know sometimes
Engineers would throw around um so certainly also also in part of reference to that I would say
Okay um so then describe their reaction to the
paper both at the time immediately and also in the years since I mean immediately actually people
were skeptical and I think rightly so um so we we evaluated on two tasks um
dependency parsing uh in in a spe very specific instance but primarily machine
translation and and really the focus was on machine translation and if something
that different uh is evaluated only on on one major task then I do think that
actually skepticism is is Justified more than Justified um and so our initial
reviews coming back from nurs were actually kind of lukewarm I would say they or they were at least the there
were some lukewarm reviews among them somebody was excited too um but
then what happened fairly quickly is that folks in a variety of different
places open AI is one of them but not the only one Sasha Rush actually uh um
who hugging face didn't exist at the time yet but who then later joined hugging face um and at the time was I
believe at is he at Harvard I think he was at Harvard at the time him uh open
Folks at open AI um uh Alec and and ilaser they very quickly started playing
around with this and because they they did see the promise that if this worked then you really could could have
something that computationally is much is a much better fit for accelerator Hardware of the day and and of the
present day too uh and so as they started playing around with it there
were some initial I remember actually having a conversation with Sasha in New York very quickly after the paper hit
archive and uh he had reimplemented the whole thing uh from scratch and there
were some issues around learning raid schedules and so forth but by and large it was working out of the box and that
was unusual because it wasn't based on an open source implementation we did release one later uh but he had done it
from scratch actually in a I believe he he actually even documented that project
as the annotated Transformer there was a blog post that that he had written up but he was uh really um he got super
excited and and again others as well uh by the fact that they could very quickly
get something that actually trains Ed least as well if not better and an order
of magnitude or more faster than lstms and that as that kind of moved through
the community it took maybe I would say half a year or so so by the time we uh
presented the paper uh in a poster session at nurs 2017 uh we basically had tons and tons
of interested people and mostly still practitioners so practitioners or somewhat more senior people who still
were very very Hands-On and then the next major event or events
actually two of them were uh the release of the GPT before it became a series uh
the generative pre-train Transformer coming out of open ey um and Bert uh
which was for bidirectional encoder representations from Transformers and um
both of those showed that you can use these now more efficient models training
them in one way or another either as language models in the case of GPT uh or as basically infilling models
in the case of Bert that you could use those models trained unsupervised just on text curated at the time it was books
that they used at the time and then they broadened into other types of data but that you could use these unsupervised
pre-trained models to actually uh uh then either tune or adapt those models
to to standard tasks in uh language understanding very very rapidly and just
get off the charts good performance and so that then really kicked off the next
major wave of of interest and excitement uh especially as then both of those in
fact actually maybe Bert in a in a in a in a very crisp way they had different model sizes in even the original
publication and they showed that just just making it much bigger uh would
massively improved performance across a pretty broad range a shockingly broad range actually of language understanding
tests and that then formed this uh in in so many ways basically the initial spark
that led to these massive infrastructure efforts that we're seeing now you know
uh it's not even culminating there's still very very much going on around
gp4 uh Claude and uh whatnot all the very very large models built by you know
the coheres open eyes and uh anthropics of this world that uh just keep improving actually as as we make them
bigger and bigger and that that the community then grasp pretty fast so basically around I would say 2019 2020
that was in full swing uh and you know we were seeing that these what is called maybe somewhat misleadingly emerging
capabilities are are manifesting Etc and so at that stage um it kind of maybe
transitioned into a mode where I was starting to get a little bit uh
what's the right term I'm really looking forward to
seeing new architectures that address some of the pretty obvious problems the Transformers still has and
inefficiencies and and and issues and so uh so basically now we're in a state when when there was a lot of energy uh
and a lot of effort spent on scaling these things up uh applying them also uh
in increasingly to other modalities uh and people getting super excited about that by other modalities you mean all
sorts of stuff so basically it took a while we can this is maybe a different slightly different question but uh
genomic data images videos um time series all sorts of stuff like that
audio um but but basically you know it had it had
at that stage now in you know maybe 2020 21 22
become kind of the default building block and in my opinion uh maybe people
uh maybe the amount of effort we invest invested in replacing it uh and
improving it actually started to be uh too little um that's that's gotten
better uh this year maybe 23 24 uh but it's still not quite I I still think we
we really um yeah it's about time we do away with it or or at least dramatically improve it the multimodality aspect was
very interesting because um one of the other things that happened basically I would say around 19 2019 2020 I had
moved back to Berlin we started working on applying in in this new group rain Berlin uh on applying Transformers to
Vision there was also a group doing this here but ultimately what we did in Berlin showed uh um around that time
2020 21 that you could actually take take a pretty much vanilla Transformer
and do image understanding with it in uh at a level of quality that certainly
rivaled and maybe superseded uh the cnns of the time and that was and the
interesting thing is uh Not only was it at least as good or maybe better but it was the same architecture that you could
also apply directly to language and that is along with other such uh uh new
modalities that other groups uh start applying this to um maybe maybe most
prominently Alpha full 2 actually uh with with protein sequences or or
ultimately also protein 3D representations of proteins um that
showed that now you know the the prior on how successful would it be if you
tried to apply this architecture or deep learning basically to some entirely
different problem the prior just shifted before it was okay maybe we can do this people in 2012 had done it with computer
vision with cnns with convolutional n networks then you know in 2015 seek to
seek and 2016 the first major launch of of gnmt of the Google neural machine
translation system people had then applied uh lsdm seek to seek lsdm um to machine translation but there
were years between these major successful new applications right uh
speech recognition and so forth was also somewhere in there but by
2020 effectively through things like the vision Transformer Alpha full 2 Etc the community community had realized
now there seems to be this thing that works for everything right and even though that's not actually true and even
though it does require did certainly still does require a lot of work to make it work people really started to be
optimistic about projects like that succeeding and so as a result they started succeeding and and right it's
it's it's really remarkable actually the one of the biggest impact one of the biggest uh uh causes for uh accelerating
impact of this paper was that it got people really optimistic about applying
that stuff to some new problem that nobody had applied it to before and about scale um and scaling it up being
one of the Surefire ways of then also making it better so that's something you can throw money at that's something you can throw time at and so suddenly the
went from this mode of oh my God there's a new thing we can do with this to yeah of course it's going to work and so we're just going to do this and this and
this and this and now we have models I can do it all together and now we can learn from Vision about language and from language about vision and actually
the lines are starting to blur and that's really I think what we need to happen even even more than it happens
today with you know modeling video modeling processes over time in order to really get to the next seismic shift
that deep learning uh uh will cause which is to really have models that have
a holistic grasp of our sensory experience of our sensory environment
and are able to really get what we how we perceive the world right and and
that's separate to certain extent get ways of or are able to perceive the
world and to effect to intervene with the world in ways that we can never right so on one hand it's about really
getting our reality and being able to not just generate stimuli that we
generally consume videos audio all this sort of stuff and understanding our Audio Visual and sensory environment and
uh mesing that with our conceptual understanding as uh captured in language but also allowing us to suddenly learn
from uh electromicroscopy data in ways that no human could ever make any sense
of right as as is increasingly the case with things like uh structural areas
like structural biology or design molecules uh in in ways that we don't
even understand not only do we not understand the rules or the the the you know the mechanisms at play we we we we
don't even understand how those design choices then have the effects that they have uh but ultimately you know enabling
this this um kind of observation and discovery of aspects of our a world that
are completely inaccessible to us humans so I wanted to clarify so it
seems like what's happened is that
um previously um in deep learning you would
have specific architectures for specific problems and now the Transformer is like a universal architecture being applied
to everything y That's right exactly and that just uh right it gets people more
optimistic about these new applications but it also enables these multimodal models that cut across many applications
that bring to bear data in one modality or modalities bring to bear data in one
modality in order to improve our understanding of another um allow us to map things from one to the other and
ultimately right if you think about it language is a way for us to codify and
communicate usually only so far only between humans a sliver of conceptual
understanding of our world right and so if I one way of conceptualizing Lang as
a phenomenon is I give you a piece of language I give you a piece of how of a world and then you can actually run that world to a certain extent
right and that involves all the stimuli and and all the modalities uh if you
want to look at it like that uh that we can perceive uh but also that we can uh
interact with in the world and for the first time it's within reach to build a
computer that can actually that has any chance of getting
close to our ability not only to capture a piece of a perceived world and communicate say in language but also
take some piece of language and then in a certain sense instantiate uh this kind of sliver of if you wish encapsulated
world or so so are large language models uh just
stochastic parrots piles of Statistics or do you believe they are emergent
Learners that encode knowledge and understanding of the world are we just
stochastic parrots or are we emergent Learners I don't know so basically I I
think these distinctions are are almost meaningless as long as we don't specifically Define what we mean by
intelligence what we mean by learning uh what we mean by parting um I don't think
it's a particularly useful or many of those if not most of those distinctions
and dividing lines are particularly actionable or insightful because we do not know how we learn we don't know if
what we call understanding is in any fundamental way truly foundationally
different from just grocking the statistics or just being a bit more a
bit better at being predicting at predicting certain phenomena right for all we know our you
know oh so sacred and oh so different learning uh abilities are just that and
if that's the case then you know surely they are learning and they're Learners
um and and so in a certain sense right
um I'm I'm of of the opinion that I don't think there's a ghost in that
machine but I highly doubt there's one in us too so or either or whichever it
is but basically um I
would on one hand I don't believe in the mechanistic interpretation of life
because it's not a machine that was designed but evolved and as a result structurally it's very different but on
the other hand I find it very difficult believe to believe any kind of you know
Duality or dualistic view that implies that there is something other than something mechanistic that makes us that
differentiates us from you know other machinery and uh as a result right it it
could just be an experimential SL data problem right to get to get them to our
level of in quotes understanding and no matter how you define understanding by the way I find it very difficult to believe that there is no understanding
in these in these machines it's not the same as ours it can't be because they're their uh the breadth of stimuli that
they're exposed to is just incre extremely limited even compared to ours but ours is also extremely limited
compared to the world right and you see that very clearly when you look at applications of deep learning to problems such as protein structure
prediction no human not even a field of scientific discipline biology over
decades was able to produce uh uh an understanding of how protein folding
happens how protein structure emerges that was anywhere close to being good enough uh to being applied in the real
world and then you come along with this blackbox thing and enough data and enough pre-training and it basically
just works now how well it works I think we still don't fully know but it works certainly better than anything humans
ever did by hand that's for sure and so it is not anymore the case that
basically their the breadth of uh data of stimuli that they perceive that the machines actually are able to tap into
is just smaller than ours it's basically just different at this stage I would say both what we see what we're you know
able to learn from and what the machines are able to learn from uh both of both of those distributions a few are still
incredibly limited when you compare it to the wealth of information that's that's out
there are llms a path towards artificial general intelligence I have no idea what
artificial general intelligence is and so I do not know I can't for the life of me give you a good answer to that
question actually that's a great answer
um uh you mentioned you know you think you you you you you you um you're almost
ready to move on to the next thing so where do you think uh the the next thing
in AI is going to be so let's see um I mean for me
personally um the next thing in AI is actually more applications of AI if you
wish and I think in the past and in the future it is different applications that
provide good forcing function or that yeah ultimately steer where new ideas uh
uh where you know we we realize that the needs are unmet and where we'll then have to improve our our our tools um I
think there's if you think about basically neural network architectures
um there's some obvious shortcomings of what we have today one is the fact that you still have to take these signals
chop them into pieces and then basically learn representations in some Vector space for each of these
pieces but the problem is this chopping into pieces is something that we can do
fairly well for signals that have been in a certain sense engineered or have evolved to have certain statistical
properties such as language for genomic data that have not
evolved you know genetics there was no reason for evolution to uh basically um evolve uh
uh genetics in such a way uh that license that kind of tokenization or
that chopping into pieces and then representing them and so and what I mean by that is that these pieces you can't have too many of them for our current uh
methods our current methods like it when there's tens or hundreds of thousands of pieces not more than that um they don't
like it when when they're too few um they also don't like it when there's still too many of these tokens although
we're getting a lot better at that now we can do like you know hundreds of thousands or millions or so but we still
have constraints around those things and and the fact that we need this chopping into pieces and that we can't learn that
in a data driven manner is a massive uh uh impediment to applying these
Technologies effectively another one is that basically today we would all agree
there are some problems that are harder than others right for for usum I mean if I ask you what's 2 plus two uh you don't
have any issue giving me a response to that if I ask you to you know I don't know find solutions to the shorting
equation for some even simplistic system I way more way harder to do uh even
though we actually understand how to do it like we understand the rules uh but um we you know to to really do execute
the computation extremely extremely difficult to do yet you can formulate
both of those queries in roughly the same length and the output might also even be okay maybe in 2 plus two the
output is also incred incredibly simplistic but uh you can imagine situations in which the inputs and
outputs have very similar shapes and yet the compute that something like uh you know gp4 or or uh
command r or whatever would allocate in order to execute to in order to try to
solve this uh problem in order to uh give you a good answer is the same
because the input and output sizes are roughly the same and that just makes no sense right so every time uh a human
will say oh I need some time to think about that that's not something our models can currently do and that's
obviously broken so um right now basically we and we we are making
progress there there's actually there's just very recently been a few really really interesting um pieces of work um
mixtures of depths actually an interesting one I think in particular uh but there is still scratching just
scratching the surface when it comes to Dynamic allocation of compute as a function of a the
difficulty of the problem as opposed to the obvious apparent size of the input
of the query and and the answer that's generated
um and I think actually already those two things if if we really made
substantial progress on them uh in connection or in the context of course of architectures that then really
support that and are efficient in that context then we would already we would already have made massive of progress um
and who knows I mean it seems like seems like we're getting there but it's uh you know
these these things are usually not revolutions they look like them in hindsight and storytelling narrative
wise you you know lots of folks want to make them into kind of these singular events that that somehow uh look like a
revolution but the reality is as it happens it's just a ton of hard work building on a ton of hard work building
on a ton of hard work and lots of people really trying their best and trying to be creative uh and so when you look at
it like that then we're probably still in the beginning of really solving some of those um or addressing some of those
taking a step back this entire conversation we've assumed that the
hardware and I've said this a few times actually looks the same and if you think about it right now
because this this's kind of a a co-evolution uh that's happening right we were joking the other day with Jensen
wrong the CEO of Nvidia that you know we were saying well we built the Transformer to fit your gpus and he's
like yeah we're building the gpus to fit your Transformers and both are true and so basically uh there is this
co-evolution but it is not clear that this specific instance of co-evolution is going is is or rather I would say
it's almost guaranteed that this specific co-evolution process is in a local Optimum and uh
meaning it is very difficult at the moment to come up with a very very different model Paradigm because the
existing model Paradigm has been engineered already now over some period of time to fit very well to this
Hardware so even though it could be a departure from Transformers and God knows which ways dumping self attention
uh replacing something with something that doesn't need tokenization would all be awesome it is actually not going to
be that fundamentally different but also it is extremely difficult to come along and build a
completely different chip completely different compute substrate uh for
machine learning deep learning AI because well all the competitive models they're all uh you know based on and
tailored to this Hardware why would it be interesting to come up with a different
chip there is this if you look at the history of computing um and actually
this is the perfect place to do this in the world I would say if you look at the history of computing um there was a switch
somewhere basically leading up to the 20s and 30s of the 20th
century the switch from analog to digital Computing and right if you look at later
Lord kelvin's tied computers and and similar super powerful analog computers
that were exactly single purpose and they had to be almost by definition in a certain sense um what is it here analog
precisions some of these some of these old analog Computing devices
um their issue was that you couldn't now apply them to even closely related other
problems because these other problems would have to be uh addressed with
sufficiently different algorithms or sufficiently different approaches that you actually had to dump out the entire computer and build it from scratch and
that's really difficult to do and so digital Computing offered the promise of being General right now with uh you know
in a single way we can actually Express and potentially address all
computable uh everything that's computable we can actually do everything that's computable but what's the price that we pay the price that we pay is
that we invest the majority of the energy that goes into computation into maintaining
discrete States so if you if you just squint at a current computer at a digital computer today the vast majority
of energy it consumes the vast majority of heat that comes out of it has to go
uh and that energy has to be expended in order to maintain that some something
that actually could be a scalar between zero and one actually or or more that now it stays either at zero or at
one but now with deep learning and maybe with
you know things like the transformer I'm not going to say the Transformer is it that would kind of be sad I would I
would think but with something like you know the the successor the successor of the Transformer
we seem to be in a position where actually we now have one algorithm that applies to many many many different
relevant problems and it's always the same algorithm so why couldn't we now go and
build an analog computer just for that one problem and that one problem is just run a Transformer or just run the
Transformer successor successor then we train such a model that can actually
train new such models we build this one analog computer for doing that and we're done we basically implemented an analog
computer that can be way more power efficient for something like you know a
complete algorithm an algorithm to learn new algorithms of the same computational
shape that now are able to handle a very broad variety of problems that we really
care about not all problems right not everything there's no completeness here or not anytime soon but at least that
way I think we could increase thermodynamic effic by orders of magnitude not just one or two but many
orders of magnitude potentially and so I do think that there's taking this big step back enormous potential for uh for
for very different ways um of of of doing all this that are that are building on still what we've now learned
through through uh you know this this this round of deep learning if you wish
um anyway yeah okay what do you see is the greatest uh their greatest potential
to benefit humanity and their greatest potential
harm superlatives are always difficult um so let's see chatbots you mean uh
systems that or or or some some kind of yeah systems that have language input
and output um well I think in in in general and this may sound like a toy but in
general the the biggest potential is that they obviate the need to formalize
or to to uh structure information in a way that is palatable to human design
machines you do not need to make a table in some way that is computer readable whatever that means you can basically
just dump out the data uh and if it's a table or tabular in in a general way
well you know maybe there's an exception maybe you have some place where in some row whatever the nth field is is uh
contains a note that says ah yeah that was the value but actually I didn't really measure it that well and then take it with a grain of salt or some
such and these things that were previously in a certain sense from a data perspective um incomprehensible to
machines have now become totally manageable um and this doesn't hold only for data that is data but it also holds
for data that is effectively algorithms so you can now basically basically have
llms or what have you whatever you want to call these things that generate code and alongside with it natural language
or sorry human language reasoning or plans that describe what the model in
quotes thinks this code should be doing and now you can go and you edit the code and your English description changes you
can edit your English description the code changes um you you can basically you know comment in totality whatever
was generated there and that really marks a departure from all of these previously formulaic languages formula
data description descriptions or data formats if you wish that is uh in a
certain sense setting us free from the the shackles of our limited uh
um of of the machines we of our previous machines limited uh uh generality if you
wish and I think that's you know in the broadest sense the biggest potential the biggest harm or again I
think yeah superlatives here are really tricky but one of the maybe
interesting um downsides that this technology uh yeah comes with and it's I
think inevitable we just have to think about ways of mitigating this um that's maybe underemphasized that's often
underemphasized I believe is that we as societies as cultures have
grown accustomed to the ability to use the difficulty of consuming but
primarily also generating text as uh security tool right so for
example um appeals in traffic court why doesn't everybody file appeal
well because it's annoying it's difficult okay why is it difficult well you need to fill out a form
okay that has become a push of a button then you need to mail it somewhere okay fine that has become a push of a button a long time ago so how about uh
appealing some other decision how about affecting anything in any kind of basis
Democratic fashion right these things are rate limited by the ability of
generating or by by our individual ability of generating language but that rate limitation is gone right you can
now generate language even conditioned on loads and loads of information at hundreds of tokens per
second on a single GPU right uh or faster and so with with some of these super large
models and as a result we really need to rethink a lot of mechanisms around
Public Services um around uh all sorts of white
collar crime um and it's not it's not at all that these that these machines or
these systems you know will take initiative uh and and anytime soon uh
and will harm us but they are amazing tools in the hands of malevolent actors
so I think that actually um as as one of of a variety but as as as an often
underemphasized example I think is is is one of the Practical dangers uh or downsides of the technology that we need
to look into and that we need to mitigate um a lot of the times people talk about content identification or or
generation you know identifying machine generated content I think that ship has sailed a long time ago we published a
paper on water marking uh uh contents of of generative models we will never go
back to any system like that uh uh to be effective for a variety of different reasons but um I think that's also
something we need to confront there's a very simplistic alternative or very obvious alternative which is we need to authenticate content or uh basically
certify that content was generated by human individual that's maybe another area uh related closely related area um
but uh and it's not the same problem actually if you think it through but uh yeah and and the list goes on but it's
it's problems like that uh that we need to think about and take care of so H how is how important are issues of trust
to um future chatbot
technology well um I mean it matters but at the end of the day it matters in a
way and it also manifests increasingly in ways that are similar to how it manifests in
humans so we've built as again societies and cultures we've we've built lots and lots
of tools that help us build trust in other individuals and we need to build a
similar Suite of tools and actually I think it's they're going to look very very similar uh that allow us to
establish trust in in in machines and systems um we have to kiss goodbye once
and for all the notion that we can do this in a way that is basically by
Design or by construction uh there will not be as far as I'm concerned um a training objective
of neural network architecture a data set of whatever combination of all those things that by Construction in an
engineering manner uh we can engineer to be trustworthy just like I can't
engineer a child to be trustworthy or a human then you know a person to be
trustworthy we have to educate them certify them um recertify them on an
ongoing basis uh and so forth and we have to understand better what
situations are in which they might not be as trustworthy and then just deal with that right this I find it I find it
sometimes almost comical when uh there are articles about hallucinations of
large language models and uh they they uh in the Press it's often described as
this I should I say almost uh this very surprising perplexing uh phenomenon when
I go to my three-year-old and I ask her a question that she factually cannot possibly know she is going to totally
hallucinate a great answer often times right in a in a shape or form that if I didn't actually know the fact I had no
way of telling whether this was hallucination or not as long as it's as as the context of the question is close
enough to uh you know something that her world model already covers well enough right I can ask her who the president of
the US is she's going to give me alth although she mostly speaks German she's going to give me an American sounding
name right U maybe maybe actually the current one she already knows but like the last last one she's still going to
give me an American sounding name and so it's not at all surprising that these that these models do that there are
certainly things we can do to improve that to mitigate some of it but there is not going to be a correct by
construction um kind of a way of engineering them to be safe in any way
comparable to say how we're trying to engineer planes to be safe right um even though I guess that also has a bit for
but for similar reasons but uh yeah um thank you so um you know we
touched on this you touched on this a little bit in your early answer but um there a lot there's a lot of discourse
about about um both um the AI might lead us to apocalypse or
Extinction um there's also on the other side um utopian discourse um what do you
think of these
conversations I think there um there is a time and a place for everything uh we
should be having some of those conversations for sure I feel the extent
the amount of energy and time and that's that's expended on some of them the
amount of attention that some of them get is totally blown out of proportion and often actually fanned by
players very often in the industry in the sector even to to further completely
other objectives and you know say for example I I do believe that and this is
completely this is actually an emergent phenomenon I don't think there's necessarily any malevolence here that's
happening but I do think that it is quite convenient uh to just given psychology
of of of of uh people in the media the masses Etc it's quite convenient to be
able to focus the the discourse on say you know things like the risk of
Extinction when you actually don't yet have an idea how to deal with some of these much more mundane problems like
disruption potential disruption or a potential for disruption of civil services Public Services uh due to the
fact that now everybody can produce like Tech at you know rapid rates or so and so yeah sure you know people are going
to do what they learn uh you know removes resistance or eases
resistance that they might otherwise encounter and I think that's what we're seeing to a large extent and so again
don't get me wrong I think a lot of these conversations need to be had but
there are many more potentially often more mundane and more pressing topics
that I feel deserve some of that if not most of that airtime attention energy
Etc um and that is a little bit unfortunate because that's really what
actually could impede progress here and could harm people on the way um and so
i' I you know in a certain sense I feel we should get better at uh uh yeah allocating resources when it
comes to which of these and and this Cuts both ways but it goes both in the utopian as well as into the dystopian
direction that these extremes right low probability High magnetude sure you know
uh need there are things we need to talk about but I feel we need to spend much more energy on the high probability and
much lower magnitude but High certainty uh space of of of outcomes right
um what excites you most about
chatbots again I think it depends a little bit on on you know what you call chat Bots I don't think chatbots by
themselves are so exciting but uh I feel ultimately especially if you
include things that can interact with lots of digital systems it it really comes back to to what we talked about
earlier to this uh the to this generalized
applicability of technology to problems in which the data and or the problem
formulation SLS solution description algorithm uh are just difficult to
squeeze into a traditional kind of machine uh uh suitable formats or format
and so it's uh you know the fact that you can now deal with say for example
language and uh and image content in a way that is almost algebraic right you
can basically you can you can describe something in language and then you can apply that function if you wish to
another piece of language in order to you know summarize a piece of text extract
certain bits and pieces of then formal information um rewrite some of it etc etc those
kinds of things uh I feel that's it's just
very and it's less about the natural way of interacting with the machine I I I
kind of don't care about how natural it is I care about how fast it is and how cheap it is uh in a in a thermodynamic
sense efficient that we have some ways to go but really it's it's just the
level of generality that that you now have it's it's uh um also yeah it's just
offers the potential to deal with the world's information uh in in in in ways
that just have absolutely been impossible before um do we need to explore
alternative approaches to Ai and why alternative to What alternative to
LMS again I mean alternative um to llms meaning or deep learning Maybe
um I mean if you're basically thinking of things like symbolic approaches or
neuros symbolic approaches I think the answer is in my mind what has worked uh better than any
other uh lens through which to look at whether or not something could be effective is does it make it faster does
it make it more thermodynamically more efficient and if the answer to that that is yes and that's that's quite
conceivable right that doing certain things in a more symbolic manner um
locally sometimes uh is is more efficient by all means let's do it
but if if we can't basically show that that's the case uh then just for the
sake of doing it differently because we think it might be
philosophically better or you know um mesh better with certain theoretical or
certain theories of of something why I don't know I wouldn't
really yeah wouldn't understand the motivation okay um and you mentioned
this therom dnamic thing so yeah um what are the what are the environmental you
know uh consequences of of chat Bots and llms um and can we make it
environmentally sustainable so there I think it's really important and in general I think this is actually I was tempted to say this uh also in the to
the last question I I think the the chatbot llm distinction is a problematic one here because uh what I really
believe is that deep learning overall uh very large models applied to you know a
very broad range of different problems have the potential to drive our Energy Efficiency through the roof and so when
it comes and this even just the allocation problems but but also um our
ability to harness energy um all sorts of uh
sustainable uh uh all sorts of sustainable energy um can be optimized
in in just in some cases evidently massively in some other cases it's going to be uh it's going to be a little more
difficult uh with these methods in ways that pay for the many many many times
over that actually it would be to me shocking if you know some years into the
future the fraction of our overall of the overall energy that is consumed by
these large models hasn't gotten very very large because it is it is to a
large extent exactly those models that will make it much much easier and much more effective actually uh and much more
sustainable um to uh in in all sorts of different ways actually
uh yeah ultimately generate or extract if you wish the energy from uh from the
system okay um final question can you talk about your current Venture
sure so uh at inceptive uh what we're doing is
ultimately building models uh and this isn't just a
AI or a dry Affair this involves an enormous amount of work uh experimental
work in a wet lab both to validate methods uh but also to generate training data but ultimately to build methods uh
or models that allow us to design molecules that uh once in the context of
say uh you're and my cells um exhibit certain pretty specific and and
increasingly broad functions um and so basically uh I guess one way of of
reformulating of rephrasing that is uh we're designing medicines with artificial intelligence but um we're
looking at a particular angle of doing this where what we're starting with is
mRNA and soon RNA molecules um that
actually are in a certain sense life complete if you wish right so there's the RNA World hypothesis that everything
in life can actually be traced back or started with uh RNA molecules it's not
clear if that's really and we might never know how life really or or where life really originated but it's enough
to know that it could have been like this to then basically um
conclude that if we could only design RNA molecules
optimally which is an incredibly challenging task we could affect all sorts of
different interventions in uh in ourselves in these very complex organisms now that's definitely science
fiction but maybe we can start with a uh with a small set of functions um such as
mRNA printing some protein uh such as you know maybe detecting the presence of
some small molecule or some specific macromolecule in the vicinity
and expressing one protein or the other whether or not based on whether or not
it's actually present um such as um
um self-amplifying or self-replicating itself which if you wish looks a lot
like uh uh like recurrence or or recursion actually if we just have some
of these simple functions can we learn how to design rnas that uh exhibit you
know any combination of such functions uh inside our cells um in ways that also
have uh you know manageable or the desired uh consequences when it comes to
innate immune responses or or or similar phenomena and thus really um enable
medicines that are programmable to an extent uh that goes Way Beyond what
we're able to do uh say certainly using small molecule medicines um but also for
more mundane reason uh reasons uh using protein biologics where um you know in
contrast to those uh RNA molecules are incredibly easy to manufacture we can in
our lab actually synthesize basically more or less any possible RNA the same
cannot def certainly cannot be said for for proteins it's much harder to do much harder to do at scale um much harder to
do uh you know if you want to create a or synthesize a broad variety of them um
and so um at the end of the day uh you know
basically finding or um enabling one
type of substrate if you wish in this case RNA as as one family of macro
molecules that can still ultimately when designed just right um affect the kinds
of interventions that constitute you know the vast majority uh maybe even of
all existing medicines and many medicines that we would like to exist um
and uh enabling that using machine learning because really the or or deep learning AI at scale because one thing
is clear at least to to us um we will never
even as you know if you wish as Humanity we will never learn conceptually how to
do that ourselves um and and this is ultimately
because so our only our only alternative is to just learn it in in the sense of
uh or or through blackbox methods such as such as deep learning um and you can think of this just as a strict
generalization of the problem of uh language understanding or or more precisely
generating human language where you know in human language at least we have an existence proof of entities like you and
me that are able to do it but we've tried for decades now to understand how we do it and what the rules are that
govern it we failed uh to understand that to conceptualize that to build a theory around that and instead we've had
to apply these datadriven blackbox mechanisms that are now actually able to do it to a pretty large uh extent both
understand and generate uh human languages
um and now in case of you know effectively learning life's languages uh which is you know at least
one of the at first languages uh say RNA that that that is the one that we want to learn first here we don't even have
an existence proof of any kind of system or organism that is able to design these things and to comprehend how they work
and so there's even less of an of a hope of of basically um being able to design
them effectively using or based on Theory based on conceptual understandings of this um uh and uh as a
result an even greater Reliance on doing this with methods like AI um now we're
starting in uh in in I would say you know the humble beginnings on on
that uh almost certainly very long journey are that we would like to design
uh mRNA molecules with um much higher chemical stability than say for example
the uh mRNA code vaccines um that are actually as a result uh accessible to a far greater
number of people right not just say two billion people uh but but maybe two
three times that because they don't require distribution using a deep Frozen cold chain um but also mRNA molecules
that have U much higher and potentially carefully modulated also over time
protein expression um subpar protein expression or two insufficient proin expression is
basically what prevents many mRNA medicines uh from actually being practical today either because you would
have to administer so much mRNA that you're going to get unwanted side effects or adverse uh effects or uh
because you ultimately end up um only expressing uh or not uh triggering
certain uh uh certain Pathways or certain phenomena in life uh if the if the protein does isn't isn't expressed
at at certain minimum rates so ultimately you could probably enable um a a pretty broad range of um
mRNA medicines that we can't actually practically uh produce and and uh
manufactured today or designed today but also um democratize access to them uh in
a in a pretty meaningful way and then expand the range of such properties and functions uh Beyond you know protein
expression and chemical stability as as we go and then eventually including things like uh recursion uh
self-amplification or replication um conditionals reacting on you know the
environment that uh that in in those cells that these molecules end up in etc
etc all right thank you