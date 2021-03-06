# encoding: utf-8

class Nanoc::CompilerTest < Nanoc::TestCase

  def new_snapshot_store
    Nanoc::SnapshotStore::InMemory.new
  end

  def test_compile_with_no_reps
    in_site do
      compile_site_here

      assert Dir['build/*'].empty?
    end
  end

  def test_compile_with_one_rep
    in_site do
      File.write('content/index.html', 'o hello')

      compile_site_here

      assert_equal [ 'build/index.html' ], Dir['build/*']
      assert File.file?('build/index.html')
      assert File.read('build/index.html') == 'o hello'
    end
  end

  def test_compile_with_two_independent_reps
    in_site do
      File.write('content/foo.html', 'o hai')
      File.write('content/bar.html', 'o bai')

      compile_site_here

      assert Dir['build/*'].size == 2
      assert File.file?('build/foo/index.html')
      assert File.file?('build/bar/index.html')
      assert File.read('build/foo/index.html') == 'o hai'
      assert File.read('build/bar/index.html') == 'o bai'
    end
  end

  def test_compile_with_two_dependent_reps
    in_site(compilation_rule_content: 'filter :erb') do
      File.write(
        'content/foo.html',
        '<%= @items["/bar.html"].compiled_content %>!!!')
      File.write(
        'content/bar.html',
        'manatee')

      compile_site_here

      assert Dir['build/*'].size == 2
      assert File.file?('build/foo/index.html')
      assert File.file?('build/bar/index.html')
      assert File.read('build/foo/index.html') == 'manatee!!!'
      assert File.read('build/bar/index.html') == 'manatee'
    end
  end

  def test_compile_with_two_mutually_dependent_reps
    in_site(compilation_rule_content: 'filter :erb') do
      File.write(
        'content/foo.html',
        '<%= @items.find { |i| i.identifier == "/bar.html" }.compiled_content %>')
      File.write(
        'content/bar.html',
        '<%= @items.find { |i| i.identifier == "/foo.html" }.compiled_content %>')

      assert_raises Nanoc::Errors::RecursiveCompilation do
        compile_site_here
      end
    end
  end

  def test_compile_should_recompile_all_reps
    in_site do
      File.write('content/foo.md', 'blah')

      site = site_here

      compiler = Nanoc::CompilerBuilder.new.build(site)
      compiler.run

      compiler = Nanoc::CompilerBuilder.new.build(site)
      compiler.run

      # At this point, even the already compiled items in the previous pass
      # should have their compiled content assigned, so this should work:
      compiler.item_rep_store.reps.each { |r| r.compiled_content }
    end
  end

  def test_disallow_multiple_snapshots_with_the_same_name
    in_site do
      # Create file
      File.write('content/stuff', 'blah')

      # Create rules
      File.open('Rules', 'w') do |io|
        io.write "compile '/**/*' do\n"
        io.write "  snapshot :aaa\n"
        io.write "  snapshot :aaa\n"
        io.write "  write '/index.html'\n"
        io.write "end\n"
        io.write "\n"
        io.write "layout '/**/*', :erb\n"
      end

      # Compile
      assert_raises Nanoc::Errors::CannotCreateMultipleSnapshotsWithSameName do
        compile_site_here
      end
    end
  end

  def test_include_compiled_content_of_active_item_at_previous_snapshot
    in_site do
      # Create item
      File.write(
        'content/index.html',
        '[<%= @item.compiled_content(:snapshot => :aaa) %>]')

      # Create rules
      File.open('Rules', 'w') do |io|
        io.write "compile '/**/*' do\n"
        io.write "  snapshot :aaa\n"
        io.write "  filter :erb\n"
        io.write "  filter :erb\n"
        io.write "  write '/index.html'\n"
        io.write "end\n"
        io.write "\n"
        io.write "layout '/**/*', :erb\n"
      end

      # Compile
      compile_site_here

      # Check
      assert_equal '[[[<%= @item.compiled_content(:snapshot => :aaa) %>]]]',
        File.read('build/index.html')
    end
  end

  def test_mutually_include_compiled_content_at_previous_snapshot
    in_site do
      # Create items
      File.open('content/a.html', 'w') do |io|
        io.write('[<%= @items["/z.html"].compiled_content(:snapshot => :guts) %>]')
      end
      File.open('content/z.html', 'w') do |io|
        io.write('stuff')
      end

      # Create rules
      File.open('Rules', 'w') do |io|
        io.write "compile '/**/*' do\n"
        io.write "  snapshot :guts\n"
        io.write "  filter :erb\n"
        io.write "  write item.identifier\n"
        io.write "end\n"
        io.write "\n"
        io.write "layout '/**/*', :erb\n"
      end

      # Compile
      compile_site_here

      # Check
      assert_equal '[stuff]', File.read('build/a.html')
      assert_equal 'stuff', File.read('build/z.html')
    end
  end

  def test_layout_with_extra_filter_args
    in_site do
      # Create item
      File.open('content/index.html', 'w') do |io|
        io.write('This is <%= @foo %>.')
      end

      # Create rules
      File.open('Rules', 'w') do |io|
        io.write "compile '/**/*' do\n"
        io.write "  filter :erb, :locals => { :foo => 123 }\n"
        io.write "  write '/index.html'\n"
        io.write "end\n"
        io.write "\n"
        io.write "layout '/**/*', :erb\n"
      end

      # Compile
      compile_site_here

      # Check
      assert_equal 'This is 123.', File.read('build/index.html')
    end
  end

  def test_change_routing_rule_and_recompile
    in_site do
      # Create items
      File.open('content/a.html', 'w') do |io|
        io.write('<h1>A</h1>')
      end
      File.open('content/b.html', 'w') do |io|
        io.write('<h1>B</h1>')
      end

      # Create rules
      File.write('Rules', <<-EOS.gsub(/^ {8}/, ''))
        compile '/**/*' do
          if item.identifier == '/a.html'
            write '/index.html'
          end
        end
      EOS

      # Compile
      compile_site_here

      # Check
      assert_equal '<h1>A</h1>', File.read('build/index.html')

      # Create rules
      File.write('Rules', <<-EOS.gsub(/^ {8}/, ''))
        compile '/**/*' do
          if item.identifier == '/b.html'
            write '/index.html'
          end
        end
      EOS

      # Compile
      compile_site_here

      # Check
      assert_equal '<h1>B</h1>', File.read('build/index.html')
    end
  end

  def test_rep_assigns
    in_site do
      # Create item
      File.open('content/index.html', 'w') do |io|
        io.write('@rep.name = <%= @rep.name %> - @item_rep.name = <%= @item_rep.name %>')
      end

      # Create rules
      File.open('Rules', 'w') do |io|
        io.write "compile '/**/*' do\n"
        io.write "  if @rep.name == :default && @item_rep.name == :default\n"
        io.write "    filter :erb\n"
        io.write "    write '/index.html'\n"
        io.write "  end\n"
        io.write "end\n"
        io.write "\n"
        io.write "layout '/**/*', :erb\n"
      end

      # Compile
      compile_site_here

      # Check
      assert_equal '@rep.name = default - @item_rep.name = default', File.read('build/index.html')
    end
  end

  def test_unfiltered_binary_item_should_not_be_moved_outside_content
    in_site do
      File.write('content/blah.dat', 'o hello')

      File.open('Rules', 'w') do |io|
        io.write "compile '/**/*' do\n"
        io.write "  write item.identifier\n"
        io.write "end\n"
        io.write "\n"
        io.write "layout '/**/*', :erb\n"
      end

      compile_site_here

      assert_equal Set.new(%w( content/blah.dat )), Set.new(Dir['content/*'])
      assert_equal Set.new(%w( build/blah.dat )), Set.new(Dir['build/*'])
    end
  end

  def test_tmp_text_items_are_removed_after_compilation
    in_site do
      # Create item
      File.open('content/index.html', 'w') do |io|
        io.write('stuff')
      end

      # Compile
      compile_site_here

      # Check
      assert Dir['tmp/text_items/*'].empty?
    end
  end

  def test_prune_do_prune_by_default
    in_site do
      File.write('content/index.html', 'o hello')
      File.write('build/crap', 'o hello')

      compile_site_here

      assert_equal [ 'build/index.html' ], Dir['build/*'].sort
    end
  end

  def test_prune_do_not_prune_if_config_says_no
    in_site do
      File.write('nanoc.yaml', "prune:\n  auto_prune: false")
      File.write('content/index.html', 'o hello')
      File.write('build/crap', 'o hello')

      compile_site_here

      assert_equal [ 'build/crap', 'build/index.html' ], Dir['build/*'].sort
    end
  end

  def test_prune_prune_if_config_says_yes
    in_site do
      File.write('nanoc.yaml', "prune:\n  auto_prune: true")
      File.write('content/index.html', 'o hello')
      File.write('build/crap', 'o hello')

      compile_site_here

      assert_equal [ 'build/index.html' ], Dir['build/*'].sort
    end
  end

  def test_compiler_dependency_on_unmet_dependency
    in_site do
      File.open('content/a.html', 'w') do |io|
        io.write('<% @items["/b.html"].compiled_content %>')
      end
      File.open('content/b.html', 'w') do |io|
        io.write('I am feeling so dependent!')
      end
      File.open('Rules', 'w') do |io|
        io.write "compile '/**/*' do\n"
        io.write "  filter :erb\n"
        io.write "  write item.identifier\n"
        io.write "end\n"
        io.write "\n"
        io.write "layout '/**/*', :erb\n"
      end

      site = site_here
      c = Nanoc::CompilerBuilder.new.build(site)
      rep = c.item_rep_store.reps_for_item(site.items['/a.html'])[0]
      dt = c.dependency_tracker
      dt.start
      assert_raises Nanoc::Errors::UnmetDependency do
        c.send :compile_rep, rep
      end
      dt.stop

      stack = dt.instance_eval { @stack }
      assert_empty stack
    end
  end

  def test_preprocess_has_unfrozen_content
    in_site do
      File.open('content/index.html', 'w') do |io|
        io.write('My name is <%= @item[:name] %>!')
      end
      File.open('Rules', 'w') do |io|
        io.write "preprocess do\n"
        io.write "  @items['/index.html'][:name] = 'What?'\n"
        io.write "end\n"
        io.write "\n"
        io.write "compile '/**/*' do\n"
        io.write "  filter :erb\n"
        io.write "  write item.identifier\n"
        io.write "end\n"
        io.write "\n"
        io.write "layout '/**/*', :erb\n"
      end

      compile_site_here

      assert_equal [ 'build/index.html' ], Dir['build/*'].sort
      assert_match(/My name is What\?!/, File.read('build/index.html'))
    end
  end

end
