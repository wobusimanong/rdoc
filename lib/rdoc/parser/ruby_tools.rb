# frozen_string_literal: false
##
# Collection of methods for writing parsers against RDoc::RubyLex and
# RDoc::RubyToken

module RDoc::Parser::RubyTools

  ##
  # Adds a token listener +obj+, but you should probably use token_listener

  def add_token_listener(obj)
    @token_listeners ||= []
    @token_listeners << obj
  end

  ##
  # Fetches the next token from the scanner

  def get_tk
    tk = nil

    if @tokens.empty? then
      if @scanner_point >= @scanner.size
        return nil
      else
        tk = @scanner[@scanner_point]
        @scanner_point += 1
        @read.push tk[:text]
        puts "get_tk1 => #{tk.inspect}" if $TOKEN_DEBUG
      end
    else
      @read.push @unget_read.shift
      tk = @tokens.shift
      puts "get_tk2 => #{tk.inspect}" if $TOKEN_DEBUG
    end

    if tk == nil || :on___end__ == tk[:kind]
      tk = nil
    end

    return nil unless tk

    if :on_symbeg == tk[:kind] then
      prev_line_no = tk[:line_no]
      prev_char_no = tk[:char_no]

      is_symbol = true
      symbol_tk = { :line_no => tk[:line_no], :char_no => tk[:char_no], :kind => :on_symbol }
      case (tk1 = get_tk)[:kind]
      when :on_ident
        symbol_tk[:text] = ":#{tk1[:text]}"
      when :on_tstring_content
        symbol_tk[:text] = ":#{tk1[:text]}"
        get_tk # skip :on_tstring_end
      when :on_tstring_end
        symbol_tk[:text] = ":#{tk1[:text]}"
      when :on_op
        symbol_tk[:text] = ":#{tk1[:text]}"
      #when :on_symbols_beg
      #when :on_qsymbols_beg
      else
        is_symbol = false
        tk = tk1
      end
      if is_symbol
        tk = symbol_tk
        # remove the identifier we just read to replace it with a symbol
        @token_listeners.each do |obj|
          obj.pop_token
        end if @token_listeners
      end
    elsif :on_tstring_beg == tk[:kind] then
      string = tk[:text]
      loop do
        inner_str_tk = get_tk
        if inner_str_tk.nil?
          break
        elsif :on_tstring_end == inner_str_tk[:kind]
          string = string + inner_str_tk[:text]
          break
        else
          string = string + inner_str_tk[:text]
        end
      end
      tk = { :line_no => tk[:line_no], :char_no => tk[:char_no], :kind => :on_tstring, :text => string }
    elsif :on_embdoc_beg == tk[:kind] then
      string = ''
      until :on_embdoc_end == (embdoc_tk = get_tk)[:kind] do
        string = string + embdoc_tk[:text]
      end
      tk = { :line_no => tk[:line_no], :char_no => tk[:char_no], :kind => :on_embdoc, :text => string }
    end

    # inform any listeners of our shiny new token
    @token_listeners.each do |obj|
      obj.add_token(tk)
    end if @token_listeners

    tk
  end

  ##
  # Reads and returns all tokens up to one of +tokens+.  Leaves the matched
  # token in the token list.

  def get_tk_until(*tokens)
    read = []

    loop do
      tk = get_tk

      case tk
      when *tokens then
        unget_tk tk
        break
      end

      read << tk
    end

    read
  end

  ##
  # Retrieves a String representation of the read tokens

  def get_tkread
    read = @read.join("")
    @read = []
    read
  end

  ##
  # Peek equivalent for get_tkread

  def peek_read
    @read.join('')
  end

  ##
  # Peek at the next token, but don't remove it from the stream

  def peek_tk
    unget_tk(tk = get_tk)
    tk
  end

  ##
  # Removes the token listener +obj+

  def remove_token_listener(obj)
    @token_listeners.delete(obj)
  end

  ##
  # Resets the tools

  def reset
    @read       = []
    @tokens     = []
    @unget_read = []
    @nest = 0
    @scanner_point = 0
  end

  def tk_nl?(tk)
    :on_nl == tk[:kind] or :on_ignored_nl == tk[:kind]
  end

  ##
  # Skips whitespace tokens including newlines if +skip_nl+ is true

  def skip_tkspace(skip_nl = true)
    tokens = []

    while (tk = get_tk) and (:on_sp == tk[:kind] or (skip_nl and tk_nl?(tk))) do
      tokens.push(tk)
    end

    unget_tk(tk)
    tokens
  end

  ##
  # Has +obj+ listen to tokens

  def token_listener(obj)
    add_token_listener obj
    yield
  ensure
    remove_token_listener obj
  end

  ##
  # Returns +tk+ to the scanner

  def unget_tk(tk)
    @tokens.unshift tk
    @unget_read.unshift @read.pop

    # Remove this token from any listeners
    @token_listeners.each do |obj|
      obj.pop_token
    end if @token_listeners

    nil
  end

end


