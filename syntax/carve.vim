" Vim syntax file
" Language:    Carve markup language
" Maintainer:  markup-carve/vim-carve
" Filenames:   *.crv
"
" Regex-based highlighting that works in classic Vim and in Neovim without
" tree-sitter. Constructs are grounded in the Carve cheat sheet. Highlight
" links target standard groups so any colorscheme renders sensible colors.

if exists('b:current_syntax')
  finish
endif

let s:save_cpo = &cpo
set cpo&vim

syntax sync minlines=50
syntax spell toplevel

" ---------------------------------------------------------------------------
" Comments: %% line, text %% trailing, and %%% ... %%% fenced block.
" ---------------------------------------------------------------------------
syntax match carveComment /%%.*$/ contains=carveTodo,@Spell
" A %%% fence line is a delimiter plus an insignificant tail (spec PART 9 S28):
" only the leading run of % is structural, so `%%% TODO` opens and `%%% end`
" closes, and `%%% html` is a comment rather than a raw block. \z( \) captures
" the opener width so \z1 closes on the SAME width, letting %%%% nest %%%.
syntax region carveCommentBlock matchgroup=carveCommentFence
      \ start=/^\s*\z(%\{3,}\).*$/ end=/^\s*\z1%\@!.*$/ contains=carveTodo,@Spell
syntax keyword carveTodo contained TODO FIXME XXX NOTE

" ---------------------------------------------------------------------------
" Headings: ATX # .. ######
" ---------------------------------------------------------------------------
syntax match carveHeading1 /^# \+\S\@=.*$/      contains=@carveInline,@Spell
syntax match carveHeading2 /^## \+\S\@=.*$/     contains=@carveInline,@Spell
syntax match carveHeading3 /^### \+\S\@=.*$/    contains=@carveInline,@Spell
syntax match carveHeading4 /^#### \+\S\@=.*$/   contains=@carveInline,@Spell
syntax match carveHeading5 /^##### \+\S\@=.*$/  contains=@carveInline,@Spell
syntax match carveHeading6 /^###### \+\S\@=.*$/ contains=@carveInline,@Spell

" ---------------------------------------------------------------------------
" Block attributes: {#id .class key=value} on their own line.
" ---------------------------------------------------------------------------
syntax match carveBlockAttr /^\s*{[^}]*}\s*$/
      \ contains=carveAttrId,carveAttrClass,carveAttrKey,carveAttrLang
syntax match carveAttrId    /#[[:alnum:]_-]\+/ contained
syntax match carveAttrClass /\.[[:alnum:]_-]\+/ contained
syntax match carveAttrKey   /[[:alnum:]_-]\+=/  contained
" The language attribute (markup-carve/carve#1114): a colon, then an optional
" tag of 1-8 alphanumeric subtags joined by hyphens.
"
" Both guards are load-bearing. The lookbehind keeps it an ITEM: an unquoted
" value may itself begin with a colon (`{key=:fr}`) at the offset the value
" starts at. The lookahead is what makes an over-long tag prose rather than a
" partial match - without it `{:toolongtag}` colours `:toolongt` as a language.
syntax match carveAttrLang  /\%({\|\s\)\@<=:\%([[:alnum:]]\{1,8}\%(-[[:alnum:]]\{1,8}\)*\)\=\%([ \t}]\)\@=/ contained

" ---------------------------------------------------------------------------
" Blockquotes and captions / attributions.
" ---------------------------------------------------------------------------
" A `>` marker takes a SPACE, or stands alone on its line. Not any `\s`:
" verified against carve-rs, `>no space`, `>>x`, `>> x` and `>\tx` are all
" paragraphs - nesting is written `> > x`, a space per marker, and a tab does
" not separate (markup-carve/carve#525).
syntax match carveBlockquote /^[ \t]*>\( \|$\).*$/ contains=@carveInline,@Spell
syntax match carveCaption    /^\s*\^ \+\S\@=.*$/ contains=@carveInline,@Spell

" ---------------------------------------------------------------------------
" Lists: -, *, +, ordered (1. 1) a. A. i. I. ...), task markers.
"
" MARKER REQUIRES CONTENT (markup-carve/carve#513): a marker followed by
" whitespace only is prose - carve-rs renders `-<space>` as `<p>-</p>`. Vim's
" `\s` is space-and-tab only and never the newline, so a BARE marker already
" failed to match; the trailing-whitespace forms are what needed the guard.
" `\S\@=` is a lookahead, so the highlighted extent is unchanged. Vim's `\S`
" also counts NBSP as non-space, which is what Carve wants.
" The BARE DOT is a marker on its own (carve#472): `.` continues an ordered
" sequence, and is the only marker allowed to drop its VALUE - the number. It
" still needs content: carve-rs renders `. ` as `<p>.</p>`, the same as every
" other content-less marker, so the guard above applies to it too.
" ---------------------------------------------------------------------------
" `+` IS NOT A BULLET (PART 9 SS17): `+ x` and `+ [ ] x` both render as
" paragraphs. Including it here painted a list marker on two shapes the engine
" calls prose, and stole the table continuation row's marker - the one `+` line
" that does open something (markup-carve/vim-carve#31).
syntax match carveListBullet /^\s*[-*] \+\S\@=/me=e-1
syntax match carveListNumber /^\s*\%(\%(\d\+\|[a-zA-Z]\|[ivxIVX]\+\)[.)]\|\.\) \+\S\@=/me=e-1
syntax match carveListTask   /^\s*[-*] \+\[[ xX\-_>?]\]/
      \ contains=carveListBullet,carveTaskMark
syntax match carveTaskMark   /\[[ xX\-_>?]\]/ contained

" Definition lists: '::' term then ':' definition.
syntax match carveDefTerm /^:: \+\S\@=.*$/ contains=@carveInline,@Spell
syntax match carveDefBody /^:\s\+\S\@=.*$/  contains=@carveInline,@Spell

" Lone + / > continuation markers at column 0 (attach next block).
syntax match carveContinuation /^[+]\s*$/

" ---------------------------------------------------------------------------
" Math spans: inline $`..` and display $$`..`  (the ```math BLOCK is
" defined with the other fenced blocks, at the end of this file).
" ---------------------------------------------------------------------------
syntax region carveMathInline matchgroup=carveMathDelim
      \ start=/\$`/ end=/`/ keepend oneline contains=@NoSpell
syntax region carveMathDisplay matchgroup=carveMathDelim
      \ start=/\$\$`/ end=/`/ keepend contains=@NoSpell

" Inline literal: !`...` -- a `!` prefix on a verbatim span, mirroring the
" $`...` math prefix. Renders as literal prose (no <code>). The `!` start is
" leftmost, so it wins over carveCode (which starts at the backtick); carveImage
" (!\[) is unaffected since the literal requires a backtick after the `!`.
syntax region carveLiteralInline matchgroup=carveLiteralDelim
      \ start=/!`/ end=/`/ oneline keepend contains=@NoSpell

" ---------------------------------------------------------------------------
" Divs / admonitions: ::: type "title" [label] ... :::
" ---------------------------------------------------------------------------
syntax match carveDivFence /^\s*:\{3,}.*$/
      \ contains=carveAdmonition,carveDivTitle,carveDivLabel
syntax keyword carveAdmonition contained note tip warning danger info success example quote
syntax match carveDivTitle /"[^"]*"/ contained
syntax match carveDivLabel /\[[^]]*\]/ contained

" A LINE BLOCK (`::: |`) and a LOCAL HARD-BREAK BLOCK (`::: \`), spec PART 9
" S23. Both are colon fences whose kind is a single punctuation mark rather
" than a word, so `carveDivFence` above already coloured the line -- as a
" generic container, which is the one thing they are not: inside them every
" intra-stanza newline is a hard break.
"
" The OPENER is what carries the distinction, so the opener is what gets a
" name; the body is ordinary inline content and the closer is an ordinary
" `:::`, which carveDivFence claims exactly as it does for every other
" container. This is the shape carve-grammars' Sublime and tree-sitter
" surfaces use for the same two constructs.
"
" Defined AFTER carveDivFence on purpose: both patterns start at the same
" column, and Vim gives the later definition priority.
syntax match carveLineBlock      /^\s*:\{3,} \+|\s*$/
syntax match carveLocalHardBreak /^\s*:\{3,} \+\\\s*$/

" The FENCED BLOCK QUOTE (`::: >`) is the third member of that family
" (markup-carve/carve#1718). It builds the block quote the marker-prefixed
" form builds, written without a marker on every line, so it links to the
" quote group rather than to Type: the sigil is the only thing on the line
" saying which container opened.
syntax match carveFencedQuote    /^\s*:\{3,} \+>\s*$/

" A BARE `::: figure` opener - the fence, its separator, the kind word, and
" NOTHING else - is a composite figure (PART 9 4c, markup-carve/carve#1215): one
" figure of ordered panels, not an admonition. `\s*$` is the whole distinction;
" `::: figure "T"` and `::: figure [g]` match nothing here and stay the generic
" container the clause says they stay.
"
" A REGION rather than a match, and the region is what carries the rule that
" GROUPS DO NOT NEST. Its `contains` omits carveFigureGroup, so a bare
" `::: figure` anywhere inside an open group - at any depth, through a quote or
" a list item as readily as directly - falls through to carveDivFence, which is
" the generic reading the clause degrades it to. A plain `syntax match` cannot
" say that: it has no notion of being inside anything, and it coloured every
" nested opener as another group.
"
" `\z(` / `\z1` is the colon-fence depth rule (PART 9 12): the region closes on
" a fence of the SAME length as the one that opened it, which is what lets
" `::::` nest inside `:::`. `keepend` stops an inner item from carrying the
" region past its own closer.
"
" The separator is a SPACE run, never a tab (grammar PART 7, MARKER SEPARATORS):
" `:::` + TAB + `figure` opens nothing, so it is left to carveDivFence, which
" over-colours it exactly as it does today.
"
" The group caption needs no rule: it is an ordinary `^ ` line below the closing
" fence, and the region ends AT that fence, so carveCaption claims it at the top
" level exactly as it claims every other caption.
syntax region carveFigureGroup
      \ matchgroup=carveFigureGroupFence
      \ start=/^\s*\z(:\{3,}\) \+figure\s*$/
      \ end=/^\s*\z1\s*$/
      \ keepend
      \ contains=ALLBUT,carveFigureGroup,@carveIncludeParts

" ---------------------------------------------------------------------------
" Tables: | cell | with |= headers, alignment and span markers.
" ---------------------------------------------------------------------------
syntax match carveTable /^\s*|.*$/ contains=carveTableSep,carveTableHeader,@carveInline,@Spell
syntax match carveTableHeader /|=[<>~]\?/ contained
syntax match carveTableSep    /[|]/ contained
syntax match carveTableRule   /^\s*|[-=:| ]\+$/

" A TABLE CONTINUATION ROW: `+` then cells, ending in a pipe
" (`continuation_row = '+', table_cell, {'|', table_cell}, '|', newline`).
" It merges into the cell above it, so it is a table row and not a list item -
" which is what the bullet rule used to make of it. Defined after carveTable so
" the two never race, and it carries the same contained groups so its cells and
" pipes highlight the way every other row's do.
syntax match carveTableContinuation /^\s*+.*|\s*$/
      \ contains=carveTableSep,carveTableHeader,@carveInline,@Spell

" ---------------------------------------------------------------------------
" Reference & footnote definitions at start of line.
"   [ref]: url   /   [^id]: footnote   /   *[ABBR]: expansion
" ---------------------------------------------------------------------------
syntax match carveRefDef   /^\s*\[[^^][^]]*\]: .*$/ contains=carveRefLabel,carveUrl
syntax match carveFootDef  /^\s*\[\^[^]]\+\]: .*$/  contains=carveFootRef,@carveInline
syntax match carveAbbrDef  /^\s*\*\[[^]]\+\]: .*$/  contains=carveAbbrLabel
syntax match carveRefLabel  /\[[^]]*\]/ contained
syntax match carveAbbrLabel /\*\[[^]]*\]/ contained

" ===========================================================================
" Inline constructs (cluster @carveInline).
" ===========================================================================

" Escapes: backslash + ASCII punctuation, and hard line break (\ at EOL).
syntax match carveEscape /\\[!-/:-@[-`{-~]/
syntax match carveHardBreak /\\$/

" Emphasis. Carve: /italic/ *bold* _underline_ ~strike~ =highlight=
" (bare ^..^ / ,..., are NOT sup/sub -- only braced {^..^} / {,..,} are).
syntax region carveItalic    matchgroup=carveDelim start=#\v/#  end=#\v/#  oneline keepend contains=carveEscape concealends
syntax region carveBold      matchgroup=carveDelim start=/\*/   end=/\*/   oneline keepend contains=carveEscape,carveItalic concealends
syntax region carveUnderline matchgroup=carveDelim start=/_/    end=/_/    oneline keepend contains=carveEscape concealends
syntax region carveStrike    matchgroup=carveDelim start=/\~/   end=/\~/   oneline keepend contains=carveEscape concealends
syntax region carveHighlight matchgroup=carveDelim start=/=/    end=/=/    oneline keepend contains=carveEscape concealends

" Bold italic, the combined `/*text*/` opener (grammar `bold_italic`). The
" boundary guards apply to the OUTER `/`; the inner `*` is part of the
" two-character token, not separately guarded. Without a rule of its own the
" carveItalic region above claimed the whole run, so a bold-italic span looked
" merely italic. Defined after carveItalic so it wins the tie at the `/`.
syntax match carveBoldItalic ,/\*\S[^*]*\*/, contains=carveEscape

" Superscript / subscript: braced forms only, {^text^} and {,text,}.
syntax match carveSuper /{\^[^{}]*\^}/ contains=carveEscape
syntax match carveSub   /{,[^{}]*,}/   contains=carveEscape

" FORCED (braced) emphasis: {/x/} {*x*} {_x_} {~x~} {=x=}. The braced spelling
" is what lets a delimiter work intraword, and the spec counts each as its own
" construct.
"
" One rule per delimiter, where there used to be one `carveBraceInline` for all
" five. That rule read `{[/*_~=][^{}]*[/*_~=]}`, which accepted a MISMATCHED
" pair: `{/x*}` closes nothing in Carve and is literal text, and it was
" coloured as emphasis. It also gave all five the same `Special` colour, so
" `{*x*}` did not look bold the way `*x*` does. Splitting fixes both, and each
" rule links to the same group as its bare twin below.
"
" Defined BEFORE the CriticMarkup regions on purpose: `{~old~>new~}` is an
" editorial substitution, not a forced strike, and carveCriticSub wins the tie
" at the `{` by being defined later.
syntax match carveForcedItalic    ,{/[^{}]\+/}, contains=carveEscape
syntax match carveForcedBold      /{\*[^{}]\+\*}/ contains=carveEscape
syntax match carveForcedUnderline /{_[^{}]\+_}/   contains=carveEscape
syntax match carveForcedStrike    /{\~[^{}]\+\~}/ contains=carveEscape
syntax match carveForcedHighlight /{=[^{}]\+=}/   contains=carveEscape

" Inline code (verbatim) and raw inline `code`{=html}.
syntax region carveCode matchgroup=carveDelim start=/`/ end=/`/ oneline keepend contains=@NoSpell
syntax match carveRawInline /`[^`]*`{=[[:alnum:]_+-]\+}/ contains=@NoSpell

" Links, autolinks, images, cross-refs, references.
syntax region carveLink matchgroup=carveDelim start=/\[/ end=/\]/ oneline keepend
      \ nextgroup=carveLinkUrl,carveLinkRef contains=@carveInlineNoLink concealends
syntax match carveLinkUrl /([^)]*)/ contained contains=carveUrl
syntax match carveLinkRef /\[[^]]*\]/ contained
syntax match carveImage /!\[[^]]*\]([^)]*)/ contains=carveUrl
" An image has the same three forms as a link, and only the leading `!` and the
" rendered element differ. Without these two rules the `!` was left as prose and
" the rest was claimed by carveLink, so `![alt][ref]` was coloured as a
" reference LINK - the surface said something false about the document.
" The full form takes a non-empty label; the collapsed one takes `[]` and reuses
" the definition the label would have named.
syntax match carveReferenceImage /!\[[^]]*\]\[[^]]\+\]/
syntax match carveCollapsedImage /!\[[^]]*\]\[\]/
syntax match carveAutolink /<\%(https\?\|ftp\|mailto\):[^>]\+>/ contains=carveUrl
syntax match carveCrossRef /<\/#[[:alnum:]_-]\+>/
syntax match carveUrl /\%(https\?\|ftp\|mailto\):[^ \t)>]\+/ contained

" Footnote references and inline footnotes.
syntax match carveFootRef /\[\^[^]]\+\]/
syntax match carveFootInline /\^\[[^]]*\]/ contains=@carveInlineNoLink

" Spans: [text]{.class}
syntax match carveSpan /\[[^]]*\]{[^}]*}/ contains=carveAttrClass,carveAttrId,carveAttrKey,carveAttrLang

" Inline attributes attached to a preceding element: {#id .class k=v}
" The language branch is spelled out rather than folded into the leading `[#.]`
" class, because the tag has a LENGTH limit: a subtag is at most eight
" characters, so `{:toolongtag}` is prose and not an attribute block at all.
syntax match carveInlineAttr /{\%([#.][^}]*\|:\%([[:alnum:]]\{1,8}\%(-[[:alnum:]]\{1,8}\)*\)\=\%([ \t][^}]*\)\=\)}/
      \ contains=carveAttrId,carveAttrClass,carveAttrKey,carveAttrLang

" Extension inline: :type[content]{attrs}
syntax match carveExtInline /:[[:alnum:]_-]\+\[[^]]*\]/

" Citations: [@key, loc; -@key2] and [+@key] -- no (url)/[ref]/{attr} tail.
" Highlights the entire bracket as a citation, with the @key sub-match.
" Key charset: [A-Za-z0-9_][A-Za-z0-9_:.#$%&+?<>~/-]*
syntax match carveCitationKey /@[[:alnum:]_][[:alnum:]_:.#$%&+?<>~\/-]*/ contained
syntax region carveCitation matchgroup=carveCitationDelim
      \ start=/\[+\?[^]]*@[[:alnum:]_]/ end=/\]\%([([\{]\)\@!/
      \ oneline keepend contains=carveCitationKey

" CodeCallout markers: <N> where N is one or more digits.
" Appears trailing in fenced-code lines and leading in callout list items.
syntax match carveCallout /<\d\+>/

" Mentions and tags.
syntax match carveMention /\%(^\|\s\)\zs@[[:alnum:]_][[:alnum:]_-]*/
syntax match carveTag     /\%(^\|\s\)\zs#[[:alnum:]_][[:alnum:]_-]*/

" RESERVED INCLUDE DIRECTIVE, `{{ path #section @opt:value }}` (spec PART 9
" S19, markup-carve/carve#291). The core leaves it literal, but a highlighter
" that does not know the shape shreds it into the constructs its own selector
" is spelled with: `#intro` IS tag syntax and `@key:value` IS mention syntax,
" so the two rules above claimed pieces of a directive they have nothing to do
" with. Defined AFTER them so it wins the tie, and `contains=` admits only the
" directive's own parts - that exclusion, not the color, is the fix.
"
" Both pads are required (`{{path}}` is ordinary text, grammar PART 6) and
" `oneline` because the directive is one token upstream and cannot cross a line
" break; an unterminated `{{` therefore never opens a region and stays prose.
syntax match carveIncludeSection /#[[:alpha:]_][[:alnum:]_-]*/ contained
syntax match carveIncludeOptionName /@[[:alpha:]_][[:alnum:]_-]*/ contained
" An option VALUE is an `attribute_value`, so it may be quoted and then carries
" spaces; read as a run of non-space characters it scoped `"two` and left
" `words"` out (markup-carve/vim-carve#35, upstream carve-grammars#411). An
" UNTERMINATED quote must fall back to the unquoted run and still stop at the
" space rather than pair with a quote further along, so both quoted
" alternatives require their closer. `\zs` anchors the value to the option's
" OWN colon: a lookbehind on the bare colon also started a second value at a
" colon inside a quoted one. Vim collections do not match a line break and the region
" is `oneline`, so the newline bound `quoted_value` needs [CARVE-P4-006] is
" already supplied here.
syntax match carveIncludeOptionValue
      \ /\%(@[[:alpha:]_][[:alnum:]_-]*:\)\@<=\%("\%(\\.\|[^"\\]\)*"\|'\%(\\.\|[^'\\]\)*'\|[^ \t}]\+\)/
      \ contained
syntax match carveIncludeOption
      \ /@[[:alpha:]_][[:alnum:]_-]*:\%("\%(\\.\|[^"\\]\)*"\|'\%(\\.\|[^'\\]\)*'\|[^ \t}]*\)/
      \ contained contains=carveIncludeOptionName,carveIncludeOptionValue
syntax match carveIncludePath /"[^"]*"\|[^#@}[:space:]"][^#@}[:space:]]*/ contained
syntax region carveInclude matchgroup=carveIncludeDelim
      \ start=/{{[ \t]\@=/ end=/[ \t]\@<=}}/
      \ oneline keepend
      \ contains=carveIncludePath,carveIncludeSection,carveIncludeOption
" The parts are reachable ONLY through the region above. Spelled as a cluster
" so carveFigureGroup's `contains=ALLBUT` can exclude them in one name: that
" list admits every contained group, and a path pattern with no sigil of its
" own then claimed `:::: figure` as a path.
syntax cluster carveIncludeParts contains=carveIncludePath,carveIncludeSection,carveIncludeOption,carveIncludeOptionName,carveIncludeOptionValue

" Symbol shortcodes :name: (word boundary; first name char is a letter, digit,
" + or -, so :+1:/:-1: match but :_x: stays literal).
syntax match carveSymbol  /\%(^\|\s\|[([]\)\zs:[[:alnum:]+-][[:alnum:]_+-]*:/

" Smart typography.
syntax match carveTypography /--\|---\|\.\.\.\|->\|(c)\|(C)\|(r)\|(R)\|(tm)\|(TM)/

" CriticMarkup: {+ins+} {-del-} {~old~>new~} {#comment#}
syntax region carveCriticIns matchgroup=carveCriticDelim start=/{+/ end=/+}/ oneline keepend
syntax region carveCriticDel matchgroup=carveCriticDelim start=/{-/ end=/-}/ oneline keepend
" Editorial substitution requires the `~>` arrow; a `{~x~}` with no arrow is a
" forced strikethrough (PART 9 S22), so the start pattern must look ahead for it.
syntax region carveCriticSub matchgroup=carveCriticDelim start=/{\~\ze[^}]*\~>/ end=/\~}/ oneline keepend
syntax region carveCriticCom matchgroup=carveCriticDelim start=/{#/ end=/#}/ oneline keepend

" A DELIMITED INLINE COMMENT, `{% ... %}` (spec PART 9 S21a,
" markup-carve/carve#1239). It hides its payload the way `%%` hides the rest of
" a line, so `contains=` admits only carveTodo: the emphasis and attribute
" rules must not reach inside, or `{% *not bold* %}` colours a bold run inside
" a comment. Defined after the inline rules so it wins a tie, and `oneline`
" because the payload cannot cross a line break. A `{%` inside a code span
" stays code: carveCode starts at the backtick, one column earlier.
syntax region carveCommentInline matchgroup=carveCommentDelim
      \ start=/{%/ end=/%}/ oneline keepend contains=carveTodo,@Spell

" Inline cluster (note: no link inside link to avoid recursion).
syntax cluster carveInlineNoLink contains=carveInclude,carveItalic,carveBold,carveBoldItalic,carveUnderline,carveStrike,carveHighlight,carveSuper,carveSub,carveCode,carveLiteralInline,carveEscape,carveHardBreak,carveMention,carveTag,carveSymbol,carveTypography,carveForcedItalic,carveForcedBold,carveForcedUnderline,carveForcedStrike,carveForcedHighlight,carveAutolink,carveCrossRef,carveFootRef,carveMathInline,carveCitation,carveCallout
syntax cluster carveInline contains=@carveInlineNoLink,carveCommentInline,carveLink,carveImage,carveReferenceImage,carveCollapsedImage,carveSpan,carveFootInline,carveRawInline,carveExtInline,carveInlineAttr,carveCriticIns,carveCriticDel,carveCriticSub,carveCriticCom

" ===========================================================================
" BLOCK OPENERS, DEFINED LAST.
"
" Vim gives the LAST-DEFINED item priority when two items can start at the same
" column, and every rule below opens on a character an inline rule also claims:
" ``` on carveCode, ~~~ on carveStrike, --- on carveTypography and carveBold.
" Defined next to the other block rules, all of them lost that tie, which is
" not a cosmetic loss - a fenced block that never opens has no payload, so the
" emphasis rules ran INSIDE the code and coloured `x = *not bold*` bold. That
" is the defect carve-grammars#309 fixed in highlight.js, here on a whole
" family of fences at once. Nothing caught it because no assertion looked
" inside a fence.
"
" So they live here, after every inline rule, and tests/highlight.crv asserts
" both halves: the fence opens, and its payload stays inert.
" ===========================================================================

" Thematic break: --- *** ___
syntax match carveRule /^\s*\%(-\{3,}\|\*\{3,}\|_\{3,}\)\s*$/

" Fenced code blocks: ```lang "Header" [Label] / ~~~
"
" NO matchgroup here, deliberately. A matchgroup match is not region content,
" so a `contains=` list cannot reach into it - which is why the info string
" used to carry no colour of its own, and why `containedin=carveCodeFence`
" resolved to nothing: a matchgroup only names a highlight group for the start
" and end matches, it is not a syntax item anything can be contained in.
" Without it the opener and closer are ordinary content, carveCodeFence
" colours the delimiter itself, and the rest of the opener line becomes an
" item the language, format, title and label rules can live inside.
syntax region carveCodeBlock
      \ start=/^\s*```.*$/ end=/^\s*```\s*$/ keepend
      \ contains=carveCodeFence,@NoSpell
syntax region carveCodeBlock
      \ start=/^\s*\~\~\~.*$/ end=/^\s*\~\~\~\s*$/ keepend
      \ contains=carveCodeFence,@NoSpell

" The fence delimiter, and after it the info string.
"
" carveCodeInfo has to stay on the OPENER LINE: reachable from the payload it
" would colour a quoted string in the code as a fence title, which is a new
" false statement in place of the missing one. Two things hold it there, and
" both are needed. It is reached through `nextgroup` rather than a region's
" `contains=` list, and nextgroup carries no `skipnl`, so it cannot cross into
" the payload. And its pattern is anchored behind the delimiter, so it stays
" put even where something reaches it anyway - carveFigureGroup contains
" ALLBUT, which would otherwise let an unanchored `.\+$` colour every line of
" a figure group.
syntax match carveCodeFence /^\s*\%(```\|\~\~\~\)/ contained
      \ nextgroup=carveCodeInfo
syntax match carveCodeInfo /\%(^\s*\%(```\|\~\~\~\)\)\@<=.\+$/ contained
      \ contains=carveCodeLang,carveRawFormat,carveCodeTitle,carveCodeLabel
syntax match carveCodeLang   /[[:alnum:]_+\/-]\+/ contained
syntax match carveRawFormat  /=\zs[[:alnum:]_+\/-]\+/ contained
syntax match carveCodeTitle  /"[^"]*"/ contained
syntax match carveCodeLabel  /\[[^]]*\]/ contained

" A RAW PASSTHROUGH BLOCK (spec PART 9 S11): a code fence whose info string is
" `=FORMAT`. The payload is handed to that format untouched, so it is not Carve
" and carries no inline groups - the same treatment carveCodeBlock gives a code
" payload, under a name of its own because the two are different constructs.
" Defined after carveCodeBlock, whose start pattern also matches this line.
syntax region carveRawBlock
      \ start=/^\s*```\s*=[[:alnum:]_+\/-]\+\s*$/ end=/^\s*```\s*$/
      \ keepend contains=carveCodeFence,@NoSpell
syntax region carveRawBlock
      \ start=/^\s*\~\~\~\s*=[[:alnum:]_+\/-]\+\s*$/ end=/^\s*\~\~\~\s*$/
      \ keepend contains=carveCodeFence,@NoSpell

" Display math as a fenced block: ```math
syntax region carveMathBlock
      \ start=/^\s*```math\s*$/ end=/^\s*```\s*$/ keepend
      \ contains=carveCodeFence,@NoSpell

" Frontmatter, only at the very top of the file: --- / ---toml / ---json.
" Last of all, because carveRule above claims the same three dashes.
syntax region carveFrontmatter matchgroup=carveFrontmatterFence
      \ start=/\%^---\%(toml\|json\|yaml\)\?$/ end=/^---$/
      \ keepend contains=@NoSpell

" ===========================================================================
" Highlight links to standard groups (colorscheme-agnostic).
" ===========================================================================
highlight default link carveHeading1 Title
highlight default link carveHeading2 Title
highlight default link carveHeading3 Title
highlight default link carveHeading4 Title
highlight default link carveHeading5 Title
highlight default link carveHeading6 Title

highlight default link carveComment       Comment
highlight default link carveCommentInline  Comment
highlight default link carveCommentDelim   Comment
highlight default link carveCommentBlock   Comment
highlight default link carveCommentFence   Comment
highlight default link carveTodo           Todo

highlight default link carveFrontmatter      PreProc
highlight default link carveFrontmatterFence Delimiter

highlight default link carveRule           Statement
highlight default link carveBlockquote     Comment
highlight default link carveCaption        Special

highlight default link carveListBullet     Statement
highlight default link carveListNumber     Statement
highlight default link carveListTask       Statement
highlight default link carveTaskMark       Special
highlight default link carveDefTerm        Type
highlight default link carveDefBody        Normal
highlight default link carveContinuation   Special

highlight default link carveCodeBlock      String
highlight default link carveCodeFence      Delimiter
highlight default link carveCodeInfo       Special
highlight default link carveCodeLang       Type
highlight default link carveRawBlock       String
highlight default link carveRawFormat      PreProc
highlight default link carveCodeTitle      String
highlight default link carveCodeLabel      Identifier

highlight default link carveMathBlock      Number
highlight default link carveMathInline     Number
highlight default link carveMathDisplay    Number
highlight default link carveMathDelim      Delimiter
highlight default link carveLiteralInline  String
highlight default link carveLiteralDelim   Delimiter

highlight default link carveFigureGroup     NONE
highlight default link carveFigureGroupFence Type
highlight default link carveDivFence       Delimiter
highlight default link carveLineBlock      Type
highlight default link carveLocalHardBreak Type
highlight default link carveFencedQuote    Comment
highlight default link carveAdmonition     Keyword
highlight default link carveDivTitle       String
highlight default link carveDivLabel       Identifier

highlight default link carveTable          Normal
highlight default link carveTableHeader    Title
highlight default link carveTableSep       Delimiter
highlight default link carveTableContinuation Normal
highlight default link carveTableRule      Delimiter

highlight default link carveRefDef         Identifier
highlight default link carveFootDef        Identifier
highlight default link carveAbbrDef        Identifier
highlight default link carveRefLabel       Identifier
highlight default link carveAbbrLabel      Identifier

highlight default link carveBlockAttr      PreProc
highlight default link carveInlineAttr     PreProc
highlight default link carveAttrId         Identifier
highlight default link carveAttrClass      Type
highlight default link carveAttrKey        Identifier
highlight default link carveAttrLang       Special

highlight default link carveEscape         Special
highlight default link carveHardBreak      Special
highlight default link carveItalic         Italic
highlight default link carveBold           Statement
highlight default link carveUnderline      Underlined
highlight default link carveStrike         Comment
highlight default link carveHighlight      Search
highlight default link carveSuper          Special
highlight default link carveSub            Special
highlight default link carveBoldItalic     Statement
highlight default link carveForcedItalic    Italic
highlight default link carveForcedBold      Statement
highlight default link carveForcedUnderline Underlined
highlight default link carveForcedStrike    Comment
highlight default link carveForcedHighlight Search
highlight default link carveDelim          Delimiter

highlight default link carveCode           String
highlight default link carveRawInline      String

highlight default link carveLink           Underlined
highlight default link carveLinkUrl        Underlined
highlight default link carveLinkRef        Identifier
highlight default link carveImage          Identifier
highlight default link carveReferenceImage Identifier
highlight default link carveCollapsedImage Identifier
highlight default link carveAutolink       Underlined
highlight default link carveCrossRef       Underlined
highlight default link carveUrl            Underlined
highlight default link carveSpan           Normal
highlight default link carveExtInline      Function

highlight default link carveFootRef        Identifier
highlight default link carveFootInline     Identifier
highlight default link carveFootDef        Identifier

highlight default link carveMention        Identifier
highlight default link carveTag            Tag

highlight default link carveIncludeDelim       Special
highlight default link carveIncludePath        String
highlight default link carveIncludeSection     Label
highlight default link carveIncludeOption      Delimiter
highlight default link carveIncludeOptionName  Identifier
highlight default link carveIncludeOptionValue Constant

highlight default link carveSymbol         Constant
highlight default link carveTypography      Special

highlight default link carveCitation       Special
highlight default link carveCitationDelim  Delimiter
highlight default link carveCitationKey    Identifier
highlight default link carveCallout        Number

highlight default link carveCriticIns      DiffAdd
highlight default link carveCriticDel      DiffDelete
highlight default link carveCriticSub      DiffChange
highlight default link carveCriticCom      Comment
highlight default link carveCriticDelim    Delimiter

" Italic is not a default group everywhere; define it if missing.
if !hlexists('Italic')
  highlight default Italic term=italic cterm=italic gui=italic
endif

let b:current_syntax = 'carve'

let &cpo = s:save_cpo
unlet s:save_cpo
