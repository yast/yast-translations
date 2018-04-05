#! /usr/bin/env ruby

# install missing gems
if !File.exist?("./.vendor")
  puts "Installing the needed Rubygems to ./.vendor/bundle ..."
  system "bundle install --path .vendor/bundle"
end

require "rubygems"
require "bundler/setup"

# require "byebug"
require "poparser"
require "readline"
require "parallel"

# YCP placeholders: %1, %2,...
def ycp_placeholders(str)
  str.to_s.scan(/%([0-9])/).flatten.uniq.sort
end

# Ruby placeholders: %s, %d,...
def ruby_placeholders(str)
  # compare also the order
  # TODO: width prefix
  str.to_s.scan(/%s|%d|%i/).flatten
end

# Ruby bracket placeholders: %{foo}, %{bar}
def ruby_bracket_placeholders(str)
  str.to_s.scan(/%{[^}]+}/).flatten.uniq.sort
end

def equal_placeholders(item)
  # handle plural forms
  if item.msgid_plural
    return item.msgstr.all? {|str| same_placeholders(item.msgid_plural, str)}
  end

  same_placeholders(item.msgid, item.msgstr)
end

def same_placeholders(msgid, msgstr)
  ycp_placeholders(msgid) == ycp_placeholders(msgstr) &&
    ruby_placeholders(msgid) == ruby_placeholders(msgstr) &&
    ruby_bracket_placeholders(msgid) == ruby_bracket_placeholders(msgstr)
end

def file_name(str)
  str.sub(/^\.\.\/\.\.\/po\//, '')
end

# unfortunately po.save_file produces wrong cached entries :-(
# we have to reimplement it
def save_po(po, file)
  array = []
  if po.header
    array << po.header.to_s
    array << ""
  end

  po.entries(true).each do |entry|
    if entry.obsolete?
      if entry.translator_comment
       comments = entry.translator_comment.to_s.split("\n")
       array.concat(comments.map {|l| "# " + l})
      end

      if entry.flag
        array << "#, " + entry.flag
      end

      str = entry.obsolete.to_s
      array << (str.split("\n").map {|l| (l.start_with?("|") ? "#~" : "#~ ") + l}.join("\n"))
      array << ""
    else
      array << entry.to_s
    end
  end

  File.write(file, array.join("\n"))
end

def ask_action(edit)
  ret = nil

  expected = ["d", "s"]
  expected << "e" if edit

  while !expected.include?(ret)
    if edit
      print "(E)dit/(D)elete/(S)kip? "
    else
      print "(D)elete/(S)kip? "
    end

    ret = $stdin.gets.chomp.downcase
  end

  ret
end

def edit(item)
  item.msgstr = Readline.readline("New text: ")
end

def ask(po, item)
  editable = !item.msgid_plural && !item.msgstr.is_a?(Array) && !item.msgstr.to_s.include?("\n")
  # byebug
  action = ask_action(editable)

  case action
  when "s"
    return false
  when "d"
    po.entries(true).delete(item)
  when "e"
    edit(item)
  end

  return true
end

def process_file(po_file, interactive)
  begin
    # puts "Loading #{po_file}..."
    po = PoParser.parse(File.read(po_file))
  rescue
    puts "ERROR: cannot parse #{file_name(po_file)}"
    puts
    return
  end

  modified = false

  po.translated.each do |item|
    next if equal_placeholders(item)

    puts "Error in #{file_name(po_file)}:"
    puts "Original: \"#{item.msgid.to_s}\""
    puts "Translation: \"#{item.msgstr.to_s}\""
    puts

    if interactive
      modified ||= ask(po, item)
    end
  end

  save_po(po, po_file) if modified
end

po_files = Dir["../../po/**/*.po"].sort

interactive = ARGV[0] == "--interactive"
parallel = ARGV[0] == "--parallel"

if parallel
  Parallel.each(po_files) { |po_file| process_file(po_file, interactive) }
else
  po_files.each { |po_file| process_file(po_file, interactive) }
end
