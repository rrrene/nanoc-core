# encoding: utf-8

class Nanoc::ConfigurationTest < Nanoc::TestCase

  def new_configuration
    Nanoc::Configuration.new({ a: 123 })
  end

  def test_get
    assert_equal new_configuration[:a], 123
  end

  def test_fetch
    assert_equal new_configuration.fetch(:a, 666), 123
    assert_equal new_configuration.fetch(:b, 666), 666
  end

  def test_set
    config = new_configuration
    config[:a] = 321
    assert_equal config[:a], 321
  end

  def test_checksum
    assert_equal new_configuration.checksum,
      '887110538e2476ff31d7fa374fe75bbed3a1d856'
  end

end
