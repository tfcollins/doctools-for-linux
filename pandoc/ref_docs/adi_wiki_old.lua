-- Pandoc filter to handle ADI mediawiki syntax
local logging = require 'logging'

-- Fix section heading introduction of bad references
function remove_attr(x)
    logging.info('Removing attributes')
    if x.attr then
        x.attr = pandoc.Attr()
        return x
    end
end

-- Reverse section heading priority
function reverse_sections(header)
    logging.info('Reversing sections')
    -- Remap header levels to reverse the order of the sections
    if header.level == 1 then
        header.level = 6
    elseif header.level == 2 then
        header.level = 5
    elseif header.level == 3 then
        header.level = 4
    elseif header.level == 4 then
        header.level = 3
    elseif header.level == 5 then
        header.level = 2
    elseif header.level == 6 then
        header.level = 1
    end
    -- header.level = 1

    return header

end

function Header(el)
    logging.info('Updating header')
    -- logging.info(el)
    el = remove_attr(el)
    el = reverse_sections(el)
    return el
end

-- #############################################################################

function expand_wiki_link(el)
    -- logging.info('Expanding link')

    el.title = ""

    -- Substring adi> to https://analog.com/
    if string.find(el.target, 'adi>') then
        el.target = string.gsub(el.target, 'adi>', 'https://analog.com/')
    end
    -- Check if context is not empty
    logging.info('Checking content')
    -- logging.info(el.content)
    -- logging.info(el.content[1].text)
    if not (el.content[1].text == nil) then
        local s = 'Text: ' .. el.content[1].text
        logging.info(s)
        if string.find(el.content[1].text, 'adi>') then
            logging.info('Found adi> in content')
            el.content[1].text = string.gsub(el.content[1].text, 'adi>', '')
        end
    end
    -- target starts with /
    if string.find(el.target, '^/') then
        el.target = 'https://wiki.analog.com' .. el.target
    end
    --
    -- Contains colons
    if string.find(el.target, ':') then
        el.target = string.gsub(el.target, ':', '/')
        el.target = 'https://wiki.analog.com' .. '/' .. el.target

    end
    -- ez>
    if string.find(el.target, 'ez>') then
        el.target = string.gsub(el.target, 'ez>', 'https://ez.analog.com/')
    end
    -- linux.github>
    if string.find(el.target, 'linux.github>') then
        -- Branch is between > and ?
        local branch = string.match(el.target, '>(.-)%?')
        -- logging.info('Branch: ' .. branch)
        characters_after_question_mark = string.match(el.target, '?(.-)$')
        -- logging.info('Characters after question mark: ' .. characters_after_question_mark)
        full_url = 'https://github.com/analogdevicesinc/linux/tree/' .. branch .. '/' .. characters_after_question_mark
        el.target = full_url
    end

    return el
end

function Link(el)
    -- logging.info('Updating link')
    -- logging.info(el)
    -- el = remove_attr(el)
    el = expand_wiki_link(el)
    return el
end

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
    local code_block_start_markers = {'<code>', '<xterm>'}
    local code_block_end_markers = {'</code>', '</xterm>'}
    local code_block_type = ''

    local whole_doc_new = {}

    for i = 1, #whole_doc.blocks do

        if not (whole_doc.blocks[i].t == 'Para') then
            
            if in_code and (whole_doc.blocks[i].t == 'BulletList') then
                logging.info('Bullet list found in code block (Handling not 100% correct)')
                -- Convert to string
                local blist_str = ''
                for k = 1, #whole_doc.blocks[i].content do
                    blist_str = blist_str .. pandoc.utils.stringify(whole_doc.blocks[i].content[k]) .. '\n'
                end
                raw_code = raw_code .. blist_str

            elseif in_code and (whole_doc.blocks[i].t == 'OrderedList') then
                logging.info('Ordered list found in code block  (Handling not 100% correct)')
                -- Convert to string
                local blist_str = ''
                for k = 1, #whole_doc.blocks[i].content do
                    blist_str = blist_str .. pandoc.utils.stringify(whole_doc.blocks[i].content[k]) .. '\n'
                end
                raw_code = raw_code .. blist_str
                
            elseif in_code then
               error('Error: Non-Para block found in code block type ' .. code_block_type .. ' | ' .. whole_doc.blocks[i].t)
            end

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


                if block.content[j].t == 'RawInline' and (not in_code) then
                    for k = 1, #code_block_start_markers do
                        if string.find(block.content[j].text, code_block_start_markers[k]) then
                            logging.info('Found code block of type ' .. code_block_start_markers[k])
                            code_block_type = code_block_start_markers[k]
                            in_code = true
                        end
                    end
                elseif block.content[j].t == 'RawInline' and in_code then
                    local end_market_check = false
                    for k = 1, #code_block_end_markers do
                        if string.find(block.content[j].text, code_block_end_markers[k]) then
                            logging.info('End of code block')
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
                        end
                    end
                elseif in_code then
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
-- Fix lists as they are interpreted as paragraphs with inline code blocks

function determine_if_para_bulleted_list(para)

    -- If para is bulleted it will be of the form Code, Link, ..., LineBreak
    -- or
    -- Code, LineBreak, Code, LineBreak

    local types = {'NA', 'NA', 'NA'}
    for i = 1, #para.content do
        -- Shift all elements to the left
        types[1] = types[2]
        types[2] = types[3]
        -- Add new element
        types[3] = para.content[i].t

        -- Check if bulleted list
        if types[1] == 'Code' and types[2] == 'LineBreak' and types[3] == 'Code' then
            return true
        end
        if types[1] == 'Code' and types[2] == 'Link' and types[3] == 'LineBreak' then
            return true
        end
    end
    return false
end

function Para(el)
    logging.info('Updating Para')
    logging.info(el)
    logging.info("BLIST: ", determine_if_para_bulleted_list(el))

    if determine_if_para_bulleted_list(el) then
        logging.info('Found bulleted list')
        local blist = {}
        local row = {}
        for i = 1, #el.content do
            if el.content[i].t == 'Code' then
                -- Remove by ignoring
            elseif el.content[i].t == 'LineBreak' then
                blist[#blist + 1] = row
                row = {}
            else
                row[#row + 1] = el.content[i]
            end
        end

        return pandoc.BulletList(blist)
        -- return el
    end
end


-- #############################################################################
-- Add code fencing for Markdown since pandoc does not insert it?

local fenced = '```\n%s\n```'
function CodeBlock (cb)
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
-- Set ordering

return {
    {Header = Header},
    {Link = Link},
    {Pandoc = Pandoc},
    {CodeBlock = CodeBlock},
    {Para = Para}
}