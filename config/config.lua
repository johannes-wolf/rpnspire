local sym = require 'ti.sym'
return {
   -- Operator store mode
   --   pop      Pop stack entry
   --   replace  Replace stack entry by variable
   --   none     No special handling
   ---@enum 'pop'|'replace'|'none'
   store_mode = 'replace',

   -- Operator with '|' mode
   --   none   No special handling
   --   smart  Join multiple operators by 'and'
   ---@enum 'none'|'smart'
   with_mode = 'smart',

   -- Stack font size
   -- A size < 9 makes asterisks unreadable
   stack_font_size = 9,

   -- Respect document settings for formatting numbers
   use_document_settings = true,

   -- Edit matrices via the matrix editor
   edit_use_matrix_editor = true,

   -- Expandable edit snippets
   -- Expanding a snippet will _not_ trigger autocompletion!
   snippets = {
      inf = sym.INFTY,
      to  = sym.CONVERT
   }
}
