require 'fileutils'
require 'kramdown-asciidoc'
require 'pathname'
require 'rjgit'
require 'yaml'

ESCAPED_PIPE = '\\|'

component, version, module_name, branch = ARGV
source_dir = 'build/markdown'
target_dir = (Pathname.new 'build/docs').expand_path
modules_dir = target_dir / 'modules'
module_dir = modules_dir / module_name
pages_dir = module_dir / 'pages'
images_dir = module_dir / 'assets/images'
nav_dir = pages_dir / '_partials'
repo = RJGit::Repo.new target_dir.to_s

repo.checkout branch
repo.remove 'modules' if modules_dir.exist?

Dir.chdir source_dir do
  [pages_dir, nav_dir, images_dir].each(&:mkpath)
  (Dir.glob '*.md').each do |infile|
    if (nav = infile == 'nav.md')
      outfile = nav_dir / 'nav.adoc'
    else
      outfile = pages_dir / %(#{infile.slice 0, infile.length - 3}.adoc)
    end
    Kramdoc.convert_file infile, to: outfile, imagesdir: 'images', postprocess: -> (asciidoc) {
      if nav
        asciidoc.lines.select {|line| line.lstrip.start_with? '*' }
          .join
          .gsub('{pp}', '++')
          .gsub('xref:', %(xref:#{module_name}:))
      elsif asciidoc.include? ESCAPED_PIPE
        asciidoc.lines.map {|line|
          (line.start_with? '|') && (line.include? ESCAPED_PIPE) ? (line.gsub ESCAPED_PIPE, '{vbar}') : line
        }.join
      end
    }
  end
  Dir.chdir 'images' do
    (Dir.glob '*').each {|infile| FileUtils.cp infile, (images_dir / infile) }
  end
end

IO.write (target_dir / 'antora.yml'), { 'name' => component, 'version' => version }.to_yaml.lines.drop(1).join
repo.add 'antora.yml'
repo.add 'modules'
