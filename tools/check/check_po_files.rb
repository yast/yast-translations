#! /usr/bin/env ruby

# This script scans the translations and checks whether the format string
# in the translated messages match the format string in the original string.

# install missing gems
if !File.exist?("./.vendor")
  puts "Installing the needed Rubygems to ./.vendor/bundle ..."
  system "bundle install --path .vendor/bundle"
end

require "rubygems"
require "bundler/setup"

#require "byebug"
require "poparser"
require "readline"
require "parallel"
require "optparse"

DEFAULT_DIR = "../../po".freeze

# get command line options
class Options
  def self.get
    options = {
      dir:         DEFAULT_DIR,
      interactive: false
    }

    OptionParser.new do |opts|
      opts.on("-i", "--[no-]interactive", "Interactively fix the broken translations") do |i|
        options[:interactive] = i
      end
      opts.on("-d", "--directory DIR", "Directory to scan (default: #{DEFAULT_DIR})") do |d|
        options[:dir] = d
      end
    end.parse!

    options
  end
end

# remember the broken translations
class BrokenTranslation
  attr_reader :file, :translations

  def initialize(f, translations:)
    @file = f
    @translations = translations
  end

  def report(options)
    return unless translations && !translations.empty?
    puts "Errors in #{file_name(file)}:"
    translations.each do |error|
      entry = PoParser::Entry.new(error.to_h)
      print(entry)
      edit(entry) if options[:interactive]
    end
  end

private

  def file_name(str)
    str.sub(/^\.\.\/\.\.\/po\//, "")
  end

  def print(entry)
    puts "Original: \"#{entry.msgid}\""
    puts "Translation: \"#{entry.msgstr}\""
    puts
  end

  def edit(entry)
    editor = PoEditor.new(file, entry)
    editor.edit
  end
end

# monkeypatch the PoParser to properly save obsolete translations back to .po file
module PoParser
  # Po class keeps all entries of a Po file
  class Po
    # unfortunately po.save_file produces wrong cached entries :-(
    # we have to reimplement it
    def save_to(file)
      array = []
      if header
        array << header.to_s
        array << ""
      end

      entries(true).each do |entry|
        if entry.obsolete?
          format_obsolete_po(array, entry)
        else
          array << entry.to_s
        end
      end

      File.write(file, array.join("\n"))
    end

  private

    def format_obsolete_po(array, entry)
      if entry.translator_comment
        comments = entry.translator_comment.to_s.split("\n")
        array.concat(comments.map { |l| "# " + l })
      end

      array << "#, " + entry.flag if entry.flag

      str = entry.obsolete.to_s
      array << str.split("\n").map { |l| (l.start_with?("|") ? "#~" : "#~ ") + l }.join("\n")
      array << ""
    end
  end
end

# validator for translations
class TranslationValidator
  # @param po_entry [PoParser::Entry] PO entry to check
  def initialize(po_entry)
    @po_entry = po_entry
  end

  attr_reader :po_entry

  def valid?
    # handle plural forms
    if po_entry.msgid_plural
      return po_entry.msgstr.all? { |str| same_placeholders(po_entry.msgid_plural, str) }
    end

    same_placeholders(po_entry.msgid, po_entry.msgstr)
  end

private

  # YCP placeholders: %1, %2,...
  def ycp_placeholders(str)
    # % not followed by $, that would be a Ruby placholder below
    str.to_s.scan(/%\d(?!\$)/).flatten.uniq.sort
  end

  # Ruby placeholders: %s, %d,...
  def ruby_placeholders(str)
    # compare also the order
    list = str.to_s.scan(/%(?:\d+\$)?[sdi]/).flatten

    # all or none items must have position prefix
    prefixed = list.count { |s| s.include?("$") }

    # no prefix used, return the list
    return list if prefixed.zero?

    # mixed unnumbered and numbered is not allowed
    # return the current list, it won't match and cause an error
    return list if list.size != prefixed

    # reorder the items and remove the position
    # ["%2$s", "%1$i"] => ["%i", "%s"]
    ret = []
    list.each do |s|
      match = s.match(/%(\d+)\$(.+)/)
      ret[match[1].to_i - 1] = "%#{match[2]}"
    end
    ret
  end

  # Ruby bracket placeholders: %{foo}, %<bar>
  def ruby_bracket_placeholders(str)
    str.to_s.scan(/%{[^}]+}|%<[^>]+>/).flatten.uniq.sort
  end

  def same_placeholders(msgid, msgstr)
    ycp_placeholders(msgid) == ycp_placeholders(msgstr) &&
      ruby_placeholders(msgid) == ruby_placeholders(msgstr) &&
      ruby_bracket_placeholders(msgid) == ruby_bracket_placeholders(msgstr)
  end
end

# Interactively edit a broken translation
class PoEditor
  attr_reader :file, :po_entry

  def initialize(file, po_entry)
    @file = file
    @po_entry = po_entry
  end

  def edit
    action = ask_action
    return if action == "s"

    po = PoParser.parse(File.read(file))

    item = po.translated.find { |t| t.msgstr.to_s == po_entry.msgstr.to_s }
    return unless item

    case action
    when "d"
      item.msgstr = ""
    when "e"
      read(item)
    end

    # save changes
    po.save_to(file) if item.msgstr.to_s != po_entry.msgstr.to_s
  end

private

  def ask_action
    ret = nil

    expected = ["d", "s"]
    expected << "e" if editable?

    until expected.include?(ret)
      if editable?
        print "(E)dit/(D)elete/(S)kip? "
      else
        print "(D)elete/(S)kip? "
      end

      ret = $stdin.gets.chomp.downcase
    end

    ret
  end

  def read(item)
    # Use pre_input_hook to fillup the input buffer with the current value
    Readline.pre_input_hook = lambda do
      Readline.insert_text(item.msgstr)
      Readline.redisplay
      Readline.pre_input_hook = nil
    end

    item.msgstr = Readline.readline("New text: ")
  end

  def editable?
    # TODO: so far this script cannot edit string arrays or plural forms
    !po_entry.msgid_plural && !po_entry.msgstr.is_a?(Array) && !po_entry.msgstr.to_s.include?("\n")
  end
end

def process_file(po_file)
  begin
    po = PoParser.parse(File.read(po_file))
  rescue
    $stderr.puts "Cannot parse file #{po_file}"
    return BrokenTranslation.new(po_file)
  end

  failed = []

  po.translated.each do |item|
    checker = TranslationValidator.new(item)
    failed << item unless checker.valid?
  end

  BrokenTranslation.new(po_file, translations: failed)
end

options = Options.get

po_files = Dir[File.join(options[:dir], "**/*.po")].sort
broken_translations = Parallel.map(po_files, progress: "Validating PO files...") do |po_file|
  process_file(po_file)
end

sum = broken_translations.inject(0) { |a, e| a + e.translations.size }
if sum.zero?
  puts "\nOK"
  exit 0
end

puts "\nFound invalid translations: #{sum}\n\n"
broken_translations.each do |bt|
  bt.report(options)
end

exit 1
