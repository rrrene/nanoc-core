# encoding: utf-8

class Nanoc::CompilerDSLTest < Nanoc::TestCase

  def setup
    super
    @rules_collection = Nanoc::RulesCollection.new
    @compiler_dsl = Nanoc::CompilerDSL.new(@rules_collection)
  end

  def test_compile
    # TODO implement
  end

  def test_layout
    # TODO implement
  end

  def test_write
    in_site do
      # Create rules
      File.write('Rules', <<EOS)
compile '/**/*' do
  write '/raw.txt'
  filter :erb
  write '/filtered.txt'
end
EOS

      # Create items
      assert Dir['content/*'].empty?
      File.write('content/input.txt', 'A <%= "X" %> B')

      # Compile
      compile_site_here

      # Check paths
      assert File.file?('build/raw.txt')
      assert File.file?('build/filtered.txt')
      assert_equal 'A <%= "X" %> B', File.read('build/raw.txt')
      assert_equal 'A X B',          File.read('build/filtered.txt')
    end
  end

  def test_preprocess_twice
    rules_collection = Nanoc::RulesCollection.new
    compiler_dsl = Nanoc::CompilerDSL.new(rules_collection)

    compiler_dsl.preprocess {}
    assert_raises(Nanoc::Errors::DoublePreprocessBlockError) do
      compiler_dsl.preprocess {}
    end
  end

  def test_write_and_snapshot
    in_site do
      # Create rules
      File.write('Rules', <<EOS)
compile '/**/*' do
  write '/foo.txt', :snapshot => :foo
  filter :erb
  write '/bar.txt'
end
EOS

      # Create items
      assert Dir['content/*'].empty?
      File.write('content/input.txt', 'stuff <%= "goes" %> here')

      # Compile
      site = site_here
      compiler = Nanoc::CompilerBuilder.new.build(site)
      compiler.run

      # Check paths
      assert File.file?('build/foo.txt')
      assert File.file?('build/bar.txt')
      assert_equal 'stuff <%= "goes" %> here', File.read('build/foo.txt')
      assert_equal 'stuff goes here',          File.read('build/bar.txt')

      # Check snapshot
      assert_equal 1, site.items.size
      item = Nanoc::ItemView.new(site.items.to_a[0], compiler.item_rep_store)
      assert_equal 'stuff <%= "goes" %> here', item.compiled_content(snapshot: :foo)
      assert_equal 'stuff goes here',          item.compiled_content(snapshot: :last)
      assert_equal '/foo.txt', item.path(snapshot: :foo)
      assert_equal '/bar.txt', item.path(snapshot: :last)
    end
  end

  def new_snapshot_store
    Nanoc::SnapshotStore::InMemory.new
  end

  def test_include_rules
    in_site do
      # Create rep
      item = Nanoc::Item.new('foo', { extension: 'bar' }, '/foo.bar')
      rep  = Nanoc::ItemRep.new(item, :default, snapshot_store: new_snapshot_store, config: Nanoc::Configuration.new({}))

      # Create a bonus rules file
      File.write('more_rules.rb', "compile '/foo.*' do end")

      # Create other necessary stuff
      site = Nanoc::SiteLoader.new.load
      site.items << item
      compiler = Nanoc::CompilerBuilder.new.build(site)
      dsl = Nanoc::CompilerDSL.new(compiler.rules_collection)

      # Include rules
      dsl.include_rules 'more_rules'

      # Check that the rule made it into the collection
      refute_nil compiler.rules_collection.compilation_rule_for(rep)
    end
  end

  def test_dsl_has_no_access_to_compiler
    assert_raises(NameError, NoMethodError) do
      @compiler_dsl.instance_eval { compiler }
    end
  end

end
