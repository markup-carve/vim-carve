((comment) @injection.content
  (#set! injection.language "comment"))

(math
  (content) @injection.content
  (#set! injection.language "latex"))

(code_block
  (language) @_lang
  (code) @injection.content
  (#carve-set-lang-from-info-string! @_lang))

(raw_block
  (raw_block_info
    (language) @injection.language)
  (content) @injection.content
  (#carve-injectable? @injection.language))

(raw_inline
  (content) @injection.content
  (raw_inline_attribute
    (language) @injection.language)
  (#carve-injectable? @injection.language))

(frontmatter
  (language) @injection.language
  (frontmatter_content) @injection.content
  (#carve-injectable? @injection.language))
