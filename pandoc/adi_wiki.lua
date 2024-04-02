-- Pandoc filter to handle ADI mediawiki syntax
local logging = require 'logging'

-- #############################################################################

function parse_code_blocks(whole_doc)
  -- Find each codeblack and format it

  -- loop through each Paragraph to find <code> and </code> then capture all text
  -- between them and convert it to a code block
  -- Code can span blocks aka Para's
  local in_code = false
  local code_block_processed = false
  local code = {}
  local new_para = {}
  local raw_code = ''
  local code_block_start_markers = {'<xterm>'}
  local code_block_end_markers = {'</xterm>'}
  local code_block_type = ''

  local whole_doc_new = {}

  for i = 1, #whole_doc.blocks do

      if not (whole_doc.blocks[i].t == 'Para') then
          
          logging.info('Adding new block of type ' .. whole_doc.blocks[i].t)
          whole_doc_new[#whole_doc_new + 1] = whole_doc.blocks[i]

      else -- blocks of type Para

          local block = whole_doc.blocks[i] -- Process paragraph
          local block_new = {} -- Filling new paragraph

          if in_code then
             raw_code = raw_code .. '\n'
          end

          -- Build contents of new block (contents is a list of objects)
          for j = 1, #block.content do

              -- Checks
              local is_str = block.content[j].t == 'Str'
              local found_end = false

              if is_str and in_code then
                  for k = 1, #code_block_end_markers do
                      if string.find(block.content[j].text, code_block_end_markers[k]) then
                        found_end = true
                      end
                  end
              end

              -- Process block

              if is_str and (not in_code) then
                  for k = 1, #code_block_start_markers do
                      if string.find(block.content[j].text, code_block_start_markers[k]) then
                          logging.info('Found code block of type ' .. code_block_start_markers[k])
                          logging.info(block.content[j].text)
                          code_block_type = code_block_start_markers[k]
                          in_code = true
                      end
                  end

              elseif found_end then
                  found_end = false
                  logging.info('End of code block')
                  logging.info(block.content[j].text)
                  logging.info('Code: ')
                  -- Remove last \n if its the last character
                  if string.sub(raw_code, -1) == '\n' then
                      raw_code = string.sub(raw_code, 1, -2)
                  end
                  logging.info(raw_code)
                  -- Convert code to code block
                  local code_block = pandoc.CodeBlock(raw_code)
                  -- new_para[#new_para + 1] = code_block
                  -- block_new[#block_new + 1] = code_block
                  block_new = code_block
                  -- Reset
                  in_code = false
                  code_block_processed = true
                  code = {}
                  raw_code = ''

              elseif in_code then
                  logging.info('Adding to code block')
                  -- logging.info(block.content[j].text)
                  if block.content[j].t == 'Str' then
                      raw_code = raw_code .. block.content[j].text
                  elseif block.content[j].t == 'Space' then
                      raw_code = raw_code .. ' '
                  elseif block.content[j].t == 'SoftBreak' then
                      raw_code = raw_code .. '\n'
                  elseif block.content[j].t == 'LineBreak' then
                      raw_code = raw_code .. '\n'
                  elseif block.content[j].t == 'RawInline' then
                      raw_code = raw_code .. block.content[j].text
                  elseif block.content[j].t == 'Code' then
                      -- Code is nested?
                      raw_code = raw_code .. block.content[j].text
                  elseif block.content[j].t == 'Strong' then
                      raw_code = raw_code .. pandoc.utils.stringify(block.content[j])
                  elseif block.content[j].t == 'BulletList' then
                      blist = block.content[j]
                      -- Convert to string
                      local blist_str = ''
                      for k = 1, #blist.content do
                          blist_str = blist_str .. pandoc.utils.stringify(blist.content[k])
                      end
                      raw_code = raw_code .. blist_str
                      
                  else
                      -- Throw error?
                      error('Error: Unknown type within code block: ' .. block.content[j].t .. ' | '.. code_block_type)
                  end
              
              else
                  block_new[#block_new + 1] = block.content[j]
              end
          end

          if in_code then
              raw_code = raw_code .. '\n'
          end

          if code_block_processed then
              code_block_processed = false
              logging.info('Adding new processed block')
              -- whole_doc_new[#whole_doc_new + 1] = pandoc.Para(block_new)
              -- whole_doc_new[#whole_doc_new + 1] = pandoc.Block(block_new)
              -- logging.info(block_new)
              whole_doc_new[#whole_doc_new + 1] = block_new
          elseif not in_code then
              logging.info('Adding new block (para)')
              -- logging.info(block_new)
              whole_doc_new[#whole_doc_new + 1] = pandoc.Para(block_new)
          end

      end
      
      -- pandoc.blocks[i] = pandoc.Para(new_para)
  end
  -- logging.info(whole_doc_new)
  return pandoc.Pandoc(whole_doc_new)
end

function Pandoc(el)
  logging.info('Updating block')
  -- logging.info(el)
  -- el = remove_attr(el)
  -- el = parse_code_blocks(el)
  return el
end


-- #############################################################################
-- Add code fencing for Markdown since pandoc does not insert it?

local fenced = '```\n%s\n```'
function CodeBlock(cb)
  -- use pandoc's default behavior if the block has classes or attribs
  if cb.classes[1] then
    return nil
  end
  -- if cb.attributes is a table check if its empty
  if type(cb.attributes) == 'table' then
    if next(cb.attributes) then
      return nil
    end
  end
  -- If first element is a \n remove it
    if string.sub(cb.text, 1, 1) == '\n' then
        cb.text = string.sub(cb.text, 2)
    end
  return pandoc.RawBlock('markdown', fenced:format(cb.text))
end

-- *****************************************************************************
-- Set order of functions to be executed

return {
  {Pandoc = Pandoc},
  {CodeBlock = CodeBlock}
}