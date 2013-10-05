# encoding: utf-8

module Nanoc

  # Generates compilers.
  #
  # @api private
  class CompilerBuilder

    def build(site)
      dependency_tracker     = self.build_dependency_tracker(site)
      rules_store            = self.build_rules_store(site.config)
      checksum_store         = self.build_checksum_store
      compiled_content_cache = self.build_compiled_content_cache
      rule_memory_store      = self.build_rule_memory_store(site)
      snapshot_store         = self.build_snapshot_store(site.config)
      item_rep_writer        = self.build_item_rep_writer(site.config)

      Nanoc::Compiler.new(
        site,
        dependency_tracker:     dependency_tracker,
        rules_store:            rules_store,
        checksum_store:         checksum_store,
        compiled_content_cache: compiled_content_cache,
        rule_memory_store:      rule_memory_store,
        snapshot_store:         snapshot_store,
        item_rep_writer:        item_rep_writer)
    end

    protected

    def build_dependency_tracker(site)
      Nanoc::DependencyTracker.new(site.items + site.layouts).tap { |s| s.load }
    end

    def build_rules_store(config)
      rules_collection = Nanoc::RulesCollection.new

      identifier = config.fetch(:rules_store_identifier, :filesystem)
      klass = Nanoc::RulesStore.named(identifier)
      rules_store = klass.new(rules_collection)

      rules_store.load_rules

      rules_store
    end

    def build_checksum_store
      Nanoc::ChecksumStore.new.tap { |s| s.load }
    end

    def build_compiled_content_cache
      Nanoc::CompiledContentCache.new.tap { |s| s.load }
    end

    def build_rule_memory_store(site)
      Nanoc::RuleMemoryStore.new(site: site).tap { |s| s.load }
    end

    def build_snapshot_store(config)
      name = config.fetch(:store_type, :in_memory)
      klass = Nanoc::SnapshotStore.named(name)
      klass.new
    end

    def build_item_rep_writer(config)
      # TODO pass options the right way
      # TODO make type customisable (:filesystem)
      Nanoc::ItemRepWriter.named(:filesystem).new({ :output_dir => config[:output_dir] })
    end

  end

end
