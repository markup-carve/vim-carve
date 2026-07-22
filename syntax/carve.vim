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
" Frontmatter (must be at the very top of the file). --- / ---toml / ---json
" ---------------------------------------------------------------------------
syntax region carveFrontmatter matchgroup=carveFrontmatterFence
      \ start=/\%^---\%(toml\|json\|yaml\)\?$/ end=/^---$/
      \ keepend contains=@NoSpell

" ---------------------------------------------------------------------------
" Comments: %% line, text %% trailing, and %%% ... %%% fenced block.
" ---------------------------------------------------------------------------
syntax match carveComment /%%.*$/ contains=carveTodo,@Spell
syntax region carveCommentBlock matchgroup=carveCommentFence
      \ start=/^%%%\s*$/ end=/^%%%\s*$/ contains=carveTodo,@Spell
syntax keyword carveTodo contained TODO FIXME XXX NOTE

" ---------------------------------------------------------------------------
" Headings: ATX # .. ######
" ---------------------------------------------------------------------------
syntax match carveHeading1 /^#\s.*$/      contains=@carveInline,@Spell
syntax match carveHeading2 /^##\s.*$/     contains=@carveInline,@Spell
syntax match carveHeading3 /^###\s.*$/    contains=@carveInline,@Spell
syntax match carveHeading4 /^####\s.*$/   contains=@carveInline,@Spell
syntax match carveHeading5 /^#####\s.*$/  contains=@carveInline,@Spell
syntax match carveHeading6 /^######\s.*$/ contains=@carveInline,@Spell

" ---------------------------------------------------------------------------
" Thematic break: --- *** ___
" ---------------------------------------------------------------------------
syntax match carveRule /^\s*\%(-\{3,}\|\*\{3,}\|_\{3,}\)\s*$/

" ---------------------------------------------------------------------------
" Block attributes: {#id .class key=value} on their own line.
" ---------------------------------------------------------------------------
syntax match carveBlockAttr /^\s*{[^}]*}\s*$/
      \ contains=carveAttrId,carveAttrClass,carveAttrKey
syntax match carveAttrId    /#[[:alnum:]_-]\+/ contained
syntax match carveAttrClass /\.[[:alnum:]_-]\+/ contained
syntax match carveAttrKey   /[[:alnum:]_-]\+=/  contained

" ---------------------------------------------------------------------------
" Blockquotes and captions / attributions.
" ---------------------------------------------------------------------------
syntax match carveBlockquote /^\s*>.*$/ contains=@carveInline,@Spell
syntax match carveCaption    /^\s*\^\s.*$/ contains=@carveInline,@Spell

" ---------------------------------------------------------------------------
" Lists: -, *, +, ordered (1. 1) a. A. i. I. ...), task markers.
" ---------------------------------------------------------------------------
syntax match carveListBullet /^\s*[-*+]\s\+/me=e-1
syntax match carveListNumber /^\s*\%(\d\+\|[a-zA-Z]\|[ivxIVX]\+\)[.)]\s\+/me=e-1
syntax match carveListTask   /^\s*[-*+]\s\+\[[ xX\-_>?]\]/
      \ contains=carveListBullet,carveTaskMark
syntax match carveTaskMark   /\[[ xX\-_>?]\]/ contained

" Definition lists: '::' term then ':' definition.
syntax match carveDefTerm /^::\s.*$/ contains=@carveInline,@Spell
syntax match carveDefBody /^:\s.*$/  contains=@carveInline,@Spell

" Lone + / > continuation markers at column 0 (attach next block).
syntax match carveContinuation /^[+]\s*$/

" ---------------------------------------------------------------------------
" Fenced code blocks: ```lang "Header" [Label] / ~~~ and raw ```=html
" ---------------------------------------------------------------------------
syntax region carveCodeBlock matchgroup=carveCodeFence
      \ start=/^\s*```.*$/ end=/^\s*```\s*$/ keepend contains=carveCodeInfo,@NoSpell
syntax region carveCodeBlock matchgroup=carveCodeFence
      \ start=/^\s*\~\~\~.*$/ end=/^\s*\~\~\~\s*$/ keepend contains=carveCodeInfo,@NoSpell
" Info string pieces on the opening fence line.
syntax match carveCodeInfo /^\s*\%(```\|\~\~\~\)=\?[[:alnum:]_+\/-]*/ contained
      \ contains=carveCodeLang,carveRawFormat
syntax match carveCodeLang   /\%(```\|\~\~\~\)\zs[[:alnum:]_+\/-]\+/ contained
syntax match carveRawFormat  /\%(```\|\~\~\~\)=\zs[[:alnum:]_+\/-]\+/ contained
syntax match carveCodeTitle  /"[^"]*"/ contained containedin=carveCodeFence
syntax match carveCodeLabel  /\[[^]]*\]/ contained containedin=carveCodeFence

" ---------------------------------------------------------------------------
" Math: ```math block, inline $`..` and display $$`..`
" ---------------------------------------------------------------------------
syntax region carveMathBlock matchgroup=carveCodeFence
      \ start=/^\s*```math\s*$/ end=/^\s*```\s*$/ keepend contains=@NoSpell
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

" ---------------------------------------------------------------------------
" Tables: | cell | with |= headers, alignment and span markers.
" ---------------------------------------------------------------------------
syntax match carveTable /^\s*|.*$/ contains=carveTableSep,carveTableHeader,@carveInline,@Spell
syntax match carveTableHeader /|=[<>~]\?/ contained
syntax match carveTableSep    /[|]/ contained
syntax match carveTableRule   /^\s*|[-=:| ]\+$/

" ---------------------------------------------------------------------------
" Reference & footnote definitions at start of line.
"   [ref]: url   /   [^id]: footnote   /   *[ABBR]: expansion
" ---------------------------------------------------------------------------
syntax match carveRefDef   /^\s*\[[^^][^]]*\]:\s.*$/ contains=carveRefLabel,carveUrl
syntax match carveFootDef  /^\s*\[\^[^]]\+\]:\s.*$/  contains=carveFootRef,@carveInline
syntax match carveAbbrDef  /^\s*\*\[[^]]\+\]:\s.*$/  contains=carveAbbrLabel
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

" Superscript / subscript: braced forms only, {^text^} and {,text,}.
syntax match carveSuper /{\^[^{}]*\^}/ contains=carveEscape
syntax match carveSub   /{,[^{}]*,}/   contains=carveEscape

" Brace forms for intraword emphasis delimiters: {*x*} {/x/} etc.
syntax match carveBraceInline /{[/*_~=][^{}]*[/*_~=]}/

" Inline code (verbatim) and raw inline `code`{=html}.
syntax region carveCode matchgroup=carveDelim start=/`/ end=/`/ oneline keepend contains=@NoSpell
syntax match carveRawInline /`[^`]*`{=[[:alnum:]_+-]\+}/ contains=@NoSpell

" Links, autolinks, images, cross-refs, references.
syntax region carveLink matchgroup=carveDelim start=/\[/ end=/\]/ oneline keepend
      \ nextgroup=carveLinkUrl,carveLinkRef contains=@carveInlineNoLink concealends
syntax match carveLinkUrl /([^)]*)/ contained contains=carveUrl
syntax match carveLinkRef /\[[^]]*\]/ contained
syntax match carveImage /!\[[^]]*\]([^)]*)/ contains=carveUrl
syntax match carveAutolink /<\%(https\?\|ftp\|mailto\):[^>]\+>/ contains=carveUrl
syntax match carveCrossRef /<\/#[[:alnum:]_-]\+>/
syntax match carveUrl /\%(https\?\|ftp\|mailto\):[^ \t)>]\+/ contained

" Footnote references and inline footnotes.
syntax match carveFootRef /\[\^[^]]\+\]/
syntax match carveFootInline /\^\[[^]]*\]/ contains=@carveInlineNoLink

" Spans: [text]{.class}
syntax match carveSpan /\[[^]]*\]{[^}]*}/ contains=carveAttrClass,carveAttrId,carveAttrKey

" Inline attributes attached to a preceding element: {#id .class k=v}
syntax match carveInlineAttr /{[#.][^}]*}/
      \ contains=carveAttrId,carveAttrClass,carveAttrKey

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

" Smart typography.
syntax match carveTypography /--\|---\|\.\.\.\|->\|(c)\|(C)\|(r)\|(R)\|(tm)\|(TM)/

" CriticMarkup: {+ins+} {-del-} {~old~>new~} {#comment#}
syntax region carveCriticIns matchgroup=carveCriticDelim start=/{+/ end=/+}/ oneline keepend
syntax region carveCriticDel matchgroup=carveCriticDelim start=/{-/ end=/-}/ oneline keepend
" Editorial substitution requires the `~>` arrow; a `{~x~}` with no arrow is a
" forced strikethrough (PART 9 S22), so the start pattern must look ahead for it.
syntax region carveCriticSub matchgroup=carveCriticDelim start=/{\~\ze[^}]*\~>/ end=/\~}/ oneline keepend
syntax region carveCriticCom matchgroup=carveCriticDelim start=/{#/ end=/#}/ oneline keepend

" Inline cluster (note: no link inside link to avoid recursion).
syntax cluster carveInlineNoLink contains=carveItalic,carveBold,carveUnderline,carveStrike,carveHighlight,carveSuper,carveSub,carveCode,carveLiteralInline,carveEscape,carveHardBreak,carveMention,carveTag,carveTypography,carveBraceInline,carveAutolink,carveCrossRef,carveFootRef,carveMathInline,carveCitation,carveCallout
syntax cluster carveInline contains=@carveInlineNoLink,carveLink,carveImage,carveSpan,carveFootInline,carveRawInline,carveExtInline,carveInlineAttr,carveCriticIns,carveCriticDel,carveCriticSub,carveCriticCom

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
highlight default link carveRawFormat      PreProc
highlight default link carveCodeTitle      String
highlight default link carveCodeLabel      Identifier

highlight default link carveMathBlock      Number
highlight default link carveMathInline     Number
highlight default link carveMathDisplay    Number
highlight default link carveMathDelim      Delimiter
highlight default link carveLiteralInline  String
highlight default link carveLiteralDelim   Delimiter

highlight default link carveDivFence       Delimiter
highlight default link carveAdmonition     Keyword
highlight default link carveDivTitle       String
highlight default link carveDivLabel       Identifier

highlight default link carveTable          Normal
highlight default link carveTableHeader    Title
highlight default link carveTableSep       Delimiter
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

highlight default link carveEscape         Special
highlight default link carveHardBreak      Special
highlight default link carveItalic         Italic
highlight default link carveBold           Statement
highlight default link carveUnderline      Underlined
highlight default link carveStrike         Comment
highlight default link carveHighlight      Search
highlight default link carveSuper          Special
highlight default link carveSub            Special
highlight default link carveBraceInline    Special
highlight default link carveDelim          Delimiter

highlight default link carveCode           String
highlight default link carveRawInline      String

highlight default link carveLink           Underlined
highlight default link carveLinkUrl        Underlined
highlight default link carveLinkRef        Identifier
highlight default link carveImage          Identifier
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
