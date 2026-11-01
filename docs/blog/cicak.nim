import nimib
import std/os
import ../theme

nbInit
nb.title = "Cicak, the chirping gecko"
# dated slug for the dev log
nb.doc.filename = nb.doc.filename.parentDir / "2026-11-01-cicak.html"
nb.useTheme(
  titleHtml = "<em>cicak</em> 🦎",
  eyebrow = "dev log · 1 November 2026",
  epigraph = "A name candidate for the REPL: the small house gecko of Southeast Asia, named after the sound it makes when it answers back.",
  meta = "naming · rendered with nimib",
  summary = "Naming: cicak, the chirping house gecko. Where it lives, what it is called, the stories around it, and why it fits a REPL.",
)

# The maps are SVGs drawn from Natural Earth country shapes (blog/cicak/*.svg);
# their colours come from the theme, so they follow light and dark mode.
nbRawHtml: """<style>
.mapbox { background: var(--out-bg); border: 1px solid var(--rule); border-radius: 6px; overflow-x: auto; margin: 1rem 0 .4rem; }
.map { display: block; width: 100%; min-width: 640px; height: auto; }
.map path { stroke: var(--ground); stroke-width: .5; }
.map .land { fill: var(--rule); }
.map .nat { fill: var(--moss); }
.map .int { fill: color-mix(in srgb, var(--moss) 40%, var(--ground)); }
.map .dot { fill: var(--ink); stroke: var(--out-bg); stroke-width: 1.5; }
.map .lbl { font-family: var(--mono); fill: var(--ink); paint-order: stroke; stroke: var(--out-bg); stroke-width: 4px; stroke-linejoin: round; }
.map .lbl .w { font-size: 15px; font-weight: 600; }
.map .lbl .lang { font-size: 11px; fill: var(--mute); }
.mapkey { font-size: .85rem; color: var(--mute); display: flex; flex-wrap: wrap; gap: 6px 18px; align-items: center; }
.mapkey .sw { width: 14px; height: 14px; border-radius: 3px; display: inline-block; vertical-align: -2px; margin-right: 6px; }
.video { position: relative; aspect-ratio: 16 / 9; margin: 1rem 0; }
.video iframe { position: absolute; inset: 0; width: 100%; height: 100%; border: 1px solid var(--rule); border-radius: 6px; }
</style>"""

nbText: """
*Cicak* (said *CHEE-chak*: in Malay and Indonesian a "c" sounds like the Italian "ci")
is the everyday name for the small house geckos of South and Southeast Asia.
The word imitates their call, *cak, cak, cak*.

## Listen to it

A common house gecko calling at night:
"""

nbRawHtml: """<div class="video"><iframe src="https://www.youtube-nocookie.com/embed/ZH39nNGYwvQ"
title="Asian House Gecko, sounds" loading="lazy" allowfullscreen
allow="encrypted-media; picture-in-picture"></iframe></div>"""

nbText: """
For a closer look at the animal itself, with Indonesian narration:
[Cicak bukan sembarang cicak (*Hemidactylus frenatus*)](https://www.youtube.com/watch?v=tdRSZ59jfmo).

## Where it lives

The main cicak, the common house gecko (*Hemidactylus frenatus*), is native to South and
Southeast Asia and Near Oceania. It lives in forest and woodland, but it does best on the
walls of houses, waiting near lamps for insects. It has hitched rides on ships and cargo
to almost every warm coast: in Mexico it was first collected in Acapulco in 1895 and now
lives in 21 of the 32 states.
"""

nbRawHtml: "<div class=\"mapbox\">" & readFile("blog/cicak/world.svg") & "</div>" &
  """<div class="mapkey"><span><span class="sw" style="background:var(--moss)"></span>Native range</span>
<span><span class="sw" style="background:color-mix(in srgb, var(--moss) 40%, var(--ground))"></span>Introduced, recorded</span>
<span>Shading is by country and approximate: in many introduced countries it lives only along the coasts or in some states. Southern China is also native but left unshaded.</span></div>"""

nbText: """
## One gecko, many names

In many of the languages where it lives, its name is also a sound: *cicak*, *tiktiki*,
*jing-jok*. Each name sits on a major city where that language is spoken.
"""

nbRawHtml: "<div class=\"mapbox\">" & readFile("blog/cicak/names.svg") & "</div>"

nbText: """
## In the cultures where it is common

- **Bali.** In Balinese belief the cecak is a form of Dewi Saraswati, the goddess who protects speech and writing.
- **Malaysia, Indonesia, India.** A gecko chirping right after someone speaks means the words are true. In Hindi and Bengali the call is heard as *thik thik thik*, "right, right, right".
- **Philippines.** A ticking butiki means a visitor or a letter is on the way.
- **Thailand.** A chirp as someone leaves the house is a bad omen, the "greeting gecko".
- **Indonesia.** *Cicak vs Buaya* (gecko against crocodile) named the 2009 clash between the anti-corruption agency KPK, the small gecko, and the police and prosecutors, the crocodile. It is now shorthand for a small underdog standing up to something big.
- **Indonesia.** Children grow up singing *Cicak-cicak di dinding*, "geckos on the wall", about a gecko sneaking up on a mosquito.

## Italian echoes

- **Ciak.** *Cicak* sounds almost like *ciak*, the Italian name for the film clapperboard, from the snap it makes. "Ciak, si gira!" starts every take, and a REPL is one quick take after another.
- **Cicalare.** From *cicala*, the cicada, Italian gets *cicalare* and *cicaleccio*, idle chatter: another small animal named after its sound, and a REPL is a chat with the compiler.
- **Cic ciac.** The Italian sound of quick little steps through puddles, close to the gecko's own *cak cak*.
- **Čičak.** Across the Adriatic, in Croatian and Serbian, *čičak* is the burdock burr that sticks to everything, and Velcro is *čičak traka*. A fitting coincidence for an animal with sticky toes.

## In Western literature

- **Italo Calvino, *Palomar* (1983).** In "Il ventre del geco", Mr. Palomar spends his evenings watching a gecko's belly through the glass of his window as it hunts under the lamp. It is the Mediterranean cousin of the cicak, from the same family of house geckos.
- **George Orwell, *Burmese Days* (1934).** Flory's bedroom in Burma has a tuktoo, the big tokay gecko named after its call: "A tuktoo clung to the wall, flat and motionless like a heraldic dragon." Later he stands "watching the tuktoo stalk a moth above the bookshelves."
- **Alfred Russel Wallace, *The Malay Archipelago* (1869).** The classic account of the region mentions small lizards in passing, but no named gecko.

## Why it fits a REPL

- It answers back, and its answer is said to confirm that what was just said is true.
- It is quick: a split-second strike after a patient wait at the lamp.
- It is adaptable: its toe pads stick to glass and ceilings, and it has settled on every warm coast of the world.
- It is resilient: it drops its tail to escape a predator and grows it back.
- The name is five letters, free on nimble, and has its own emoji 🦎.

## Sources

[Common house gecko](https://en.wikipedia.org/wiki/Common_house_gecko) (range, names, folklore),
[Cicak](https://id.wikipedia.org/wiki/Cicak) on Indonesian Wikipedia (the call, Bali),
[Konfrontasi Cicak dan Buaya](https://id.wikipedia.org/wiki/Cicak_vs_Buaya),
[Burmese Days](https://gutenberg.net.au/ebooks02/0200051.txt),
[The Malay Archipelago](https://www.gutenberg.org/ebooks/2530).
Maps drawn from [Natural Earth](https://www.naturalearthdata.com/) country shapes.
"""

nbSave
