require "bundler/gem_tasks"
require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList['test/**/*_test.rb']
end

task :default => :test


desc "show how to release"
task :help do
  puts <<END
How to release:

    $ git checkout dev
    $ git diff
    $ which ruby
    $ rake test                 # for confirmation
    $ git checkout -b rel-1.0   # or git checkout rel-1.0
    $ rake edit rel=1.0.0
    $ git diff
    $ git commit -a -m "release preparation for 1.0.0"
    $ rake build                # for confirmation
    $ rake install              # for confirmation
    $ #rake release
    $ gem push pkg/rake-jet_router-1.0.0.gem
    $ git tag v1.0.0
    $ git push -u origin rel-1.0
    $ git push --tags
END

end


desc "edit files (for release preparation)"
task :edit do
  rel = ENV['rel']  or
    raise "ERROR: 'rel' environment variable expected."
  filenames = Dir[*%w[lib/**/*.rb test/**/*_test.rb test/test_helper.rb *.gemspec]]
  filenames.each do |fname|
    File.open(fname, 'r+', encoding: 'utf-8') do |f|
      content = f.read()
      x = content.gsub!(/\$Release:.*?\$/, "$Release: #{rel} $")
      if x.nil?
        puts "[_] #{fname}"
      else
        puts "[C] #{fname}"
        f.rewind()
        f.truncate(0)
        f.write(content)
      end
    end
  end
end
